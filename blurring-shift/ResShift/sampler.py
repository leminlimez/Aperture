#!/usr/bin/env python
# -*- coding:utf-8 -*-
# Power by Zongsheng Yue 2022-07-13 16:59:27

import os, sys, math, random, time

import matplotlib.pyplot as plt
import cv2
import numpy as np
from pathlib import Path
from loguru import logger
from omegaconf import OmegaConf
from contextlib import nullcontext

from utils import util_net
from utils import util_image
from utils import util_common

import torch
import torch.nn.functional as F
import torch.distributed as dist
import torch.multiprocessing as mp

from datapipe.datasets import create_dataset
from utils.util_image import ImageSpliterTh, Bicubic
from skimage import img_as_ubyte


class BaseSampler:
    def __init__(
            self,
            configs,
            sf=4,
            use_amp=True,
            chop_size=128,
            chop_stride=128,
            chop_bs=1,
            padding_offset=16,
            seed=10000,
            ):
        '''
        Input:
            configs: config, see the yaml file in folder ./configs/
            sf: int, super-resolution scale
            seed: int, random seed
        '''
        self.configs = configs
        self.sf = sf
        self.chop_size = chop_size
        self.chop_stride = chop_stride
        self.chop_bs = chop_bs
        self.seed = seed
        self.use_amp = use_amp
        self.padding_offset = padding_offset

        self.setup_dist()  # setup distributed training: self.num_gpus, self.rank

        self.setup_seed()

        self.build_model()

    def setup_seed(self, seed=None):
        seed = self.seed if seed is None else seed
        random.seed(seed)
        np.random.seed(seed)
        torch.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)

    def setup_dist(self, gpu_id=None):
        num_gpus = torch.cuda.device_count()

        if num_gpus > 1:
            # if mp.get_start_method(allow_none=True) is None:
                # mp.set_start_method('spawn')
            # rank = int(os.environ['LOCAL_RANK'])
            # torch.cuda.set_device(rank % num_gpus)
            # dist.init_process_group(backend='nccl', init_method='env://')
            rank = 0
            torch.cuda.set_device(rank)

        self.num_gpus = num_gpus
        self.rank = int(os.environ['LOCAL_RANK']) if num_gpus > 1 else 0

    def write_log(self, log_str):
        if self.rank == 0:
            print(log_str, flush=True)

    def build_model(self):
        # diffusion model
        log_str = f'Building the diffusion model with length: {self.configs.diffusion.params.steps}...'
        self.write_log(log_str)
        self.base_diffusion = util_common.instantiate_from_config(self.configs.diffusion)
        model = util_common.instantiate_from_config(self.configs.model).cuda()
        ckpt_path =self.configs.model.ckpt_path
        assert ckpt_path is not None
        self.write_log(f'Loading Diffusion model from {ckpt_path}...')
        ckpt = torch.load(ckpt_path, map_location=f"cuda:{self.rank}")
        if 'state_dict' in ckpt:
            util_net.reload_model(model, ckpt['state_dict'])
        else:
            util_net.reload_model(model, ckpt)
        self.freeze_model(model)
        self.model = model.eval()

        # autoencoder model
        if self.configs.autoencoder.params.get("lora_tune_decoder", False):
            lora_vae_state = ckpt['lora_vae']
        elif self.configs.autoencoder.get("tune_decoder", False):
            vae_state = ckpt['vae']
        if self.configs.autoencoder is not None:
            params = self.configs.autoencoder.get('params', dict)
            autoencoder = util_common.get_obj_from_str(self.configs.autoencoder.target)(**params)
            autoencoder.cuda()
            if self.configs.autoencoder.params.get("lora_tune_decoder", False):
                ckpt_path = self.configs.autoencoder.ckpt_path
                self.write_log(f'Loading AutoEncoder model from {ckpt_path}...')
                self.load_model_lora(autoencoder, ckpt_path, tag='autoencoder')
                autoencoder.load_state_dict(lora_vae_state, strict=False)
            elif self.configs.autoencoder.get("tune_decoder", False):
                ckpt_path = self.configs.autoencoder.ckpt_path
                self.write_log(f'Loading AutoEncoder model from {ckpt_path}...')
                self.load_model(autoencoder, ckpt_path)
                ckpt_path =self.configs.model.ckpt_path
                self.write_log(f'Loading Finetuned decoder from {ckpt_path}...')
                autoencoder.load_state_dict(vae_state, strict=False)
            else:
                ckpt_path = self.configs.autoencoder.ckpt_path
                self.write_log(f'Loading AutoEncoder model from {ckpt_path}...')
                self.load_model(autoencoder, ckpt_path)
            autoencoder.eval()
            self.autoencoder = autoencoder
        else:
            self.autoencoder = None

    def load_model_lora(self, model, ckpt_path=None, tag='model'):
        if self.rank == 0:
            self.write_log(f'Loading {tag} from {ckpt_path}...')
        ckpt = torch.load(ckpt_path, map_location=f"cuda:{self.rank}")
        num_success = 0
        for key, value in model.named_parameters():
            if key in ckpt:
                value.data.copy_(ckpt[key])
                num_success += 1
            else:
                key_parts = key.split('.')
                if 'conv' in key_parts:
                    key_parts.remove('conv')
                new_key = '.'.join(key_parts)
                if new_key in ckpt:
                    value.data.copy_(ckpt[new_key])
                    num_success += 1
        assert num_success == len(ckpt)
        if self.rank == 0:
            self.write_log('Loaded Done')

    def load_model(self, model, ckpt_path=None):
        state = torch.load(ckpt_path, map_location=f"cuda:{self.rank}")
        if 'state_dict' in state:
            state = state['state_dict']
        util_net.reload_model(model, state)

    def freeze_model(self, net):
        for params in net.parameters():
            params.requires_grad = False

class ResShiftSampler(BaseSampler):
    def sample_func(self, y0, noise_repeat=False, mask=False):
        '''
        Input:
            y0: n x c x h x w torch tensor, low-quality image, [-1, 1], RGB
            mask: image mask for inpainting
        Output:
            sample: n x c x h x w, torch tensor, [-1, 1], RGB
        '''
        if noise_repeat:
            self.setup_seed()

        offset = self.padding_offset
        ori_h, ori_w = y0.shape[2:]
        if not (ori_h % offset == 0 and ori_w % offset == 0):
            flag_pad = True
            pad_h = (math.ceil(ori_h / offset)) * offset - ori_h
            pad_w = (math.ceil(ori_w / offset)) * offset - ori_w
            y0 = F.pad(y0, pad=(0, pad_w, 0, pad_h), mode='reflect')
        else:
            flag_pad = False

        if self.configs.model.params.cond_lq and mask is not None:
            model_kwargs={
                    'lq':y0,
                    'mask': mask,
                    }
        elif self.configs.model.params.cond_lq:
            model_kwargs={'lq':y0,}
        else:
            model_kwargs = None

        results = self.base_diffusion.p_sample_loop(
                y=y0,
                model=self.model,
                first_stage_model=self.autoencoder,
                noise=None,
                noise_repeat=noise_repeat,
                clip_denoised=(self.autoencoder is None),
                denoised_fn=None,
                model_kwargs=model_kwargs,
                progress=False,
                )    # This has included the decoding for latent space

        if flag_pad:
            results = results[:, :, :ori_h*self.sf, :ori_w*self.sf]

        return results.clamp_(-1.0, 1.0)

    def inference(self, in_path, out_path, image, mask_path=None, mask_back=True, bs=1, noise_repeat=False):
        '''
        Inference demo.
        Input:
            in_path: str, folder or image path for LQ image
            out_path: str, folder save the results
            bs: int, default bs=1, bs % num_gpus == 0
            mask_path: image mask for inpainting
        '''
        def _process_per_image(im_lq_tensor, mask=None):
            '''
            Input:
                im_lq_tensor: b x c x h x w, torch tensor, [-1, 1], RGB
                mask: image mask for inpainting, [-1, 1], 1 for unknown area
            Output:
                im_sr: h x w x c, numpy array, [0,1], RGB
            '''

            context = torch.cuda.amp.autocast if self.use_amp else nullcontext
            if im_lq_tensor.shape[2] > self.chop_size or im_lq_tensor.shape[3] > self.chop_size:
                im_spliter = ImageSpliterTh(
                        im_lq_tensor,
                        self.chop_size,
                        stride=self.chop_stride,
                        sf=self.sf,
                        extra_bs=self.chop_bs,
                        )
                for im_lq_pch, index_infos in im_spliter:
                    mask_pch = None
                    with context():
                        im_sr_pch = self.sample_func(
                                im_lq_pch,
                                noise_repeat=noise_repeat,
                                mask=None,
                                )     # 1 x c x h x w, [-1, 1]
                    im_spliter.update(im_sr_pch, index_infos)
                im_sr_tensor = im_spliter.gather()
            else:
                with context():
                    im_sr_tensor = self.sample_func(
                            im_lq_tensor,
                            noise_repeat=noise_repeat,
                            mask=None,
                            )     # 1 x c x h x w, [-1, 1]

            im_sr_tensor = im_sr_tensor * 0.5 + 0.5
            return im_sr_tensor

        if self.rank == 0:
            pass

        if self.num_gpus > 1:
            dist.barrier()

        im_lq = image

        transformation_time = time.time()

        min_dim = 1280

        if any(dim > min_dim for dim in im_lq.shape):
            max_dim = max(im_lq.shape)
            powers = [2 ** i for i in range(2, 8)]

            scale = 1.

            for x in powers:
                if max_dim / x < min_dim:
                    scale = 1 / x
                    break
        
            print(f"\nScale: {scale}, lq dimensions: {im_lq.shape}")
            
            transformation = Bicubic(scale=scale, out_shape=None, activate_matlab=False, resize_back=False)
            im_lq = transformation(im_lq)

        print(f"Transformation time: {time.time() - transformation_time}")

        print(im_lq.shape)

        print(f"cuda: {torch.cuda.is_available()}")

        inference_time = time.time()

        im_lq_tensor = util_image.img2tensor(im_lq).cuda()              # 1 x c x h x w
        print(f"im_lq_tensor: {im_lq_tensor.shape}")
        im_sr_tensor = _process_per_image(
                (im_lq_tensor - 0.5) / 0.5,
                mask=None,
                )    
        
        print(f"Inference time: {time.time() - inference_time}")

        converting_time = time.time()

        im_sr = util_image.tensor2img(im_sr_tensor, rgb2bgr=True, min_max=(0.0, 1.0))
        im_sr = img_as_ubyte(im_sr)

        print(f"Converting time: {time.time() - converting_time}")

        self.write_log(f"Returning image...")
        return im_sr


if __name__ == '__main__':
    pass

