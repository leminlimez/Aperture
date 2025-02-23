FROM continuumio/miniconda3

# Set up Conda and Python version
RUN conda config --append channels conda-forge && \
    conda create -n resshift python=3.10 -y 

# Activate environment and install dependencies
SHELL ["conda", "run", "-n", "resshift", "/bin/bash", "-c"]

# Install PyTorch separately from the official channel
# RUN conda install pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch -c nvidia -y

# Copy dependency files
COPY requirements.txt .
COPY environment.yml .

# RUN conda install pytorch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 pytorch-cuda=11.8 -c pytorch -c nvidia
# RUN conda pip install torch==2.1.2+cu118 --extra-index-url https://download.pytorch.org/whl/cu118

# Install remaining dependencies
RUN pip install -r requirements.txt
# RUN conda env update --name resshift --file environment.yml --prune
# RUN pip install google protobuf
# RUN pip install --upgrade google-api-python-client
RUN conda install protobuf