from flask import Flask, request, jsonify
import matplotlib.pyplot as plt
import cv2
import numpy as np
from inference_resshift import run_inference
import base64
import time
from PIL import Image

app = Flask(__name__)

save_dir = './results/deblurred.jpg'
# API_KEY = "name-and-nomber"
# header = 'X-API-Key'

resshift_sampler_ = None
args_ = None


@app.before_request
def load_model():
    global resshift_sampler_
    global args_
    resshift_sampler_, args_ = run_inference(image=None, load_model=True, sampler=None)

    print(f"\nFinished loading model...")


# @app.route('/run_inference', methods=['POST'])
# def index():
#     start = time.time()

#     img = request.get_json()
#     buffer = img['image']
#     # print(buffer)
#     img = base64.b64decode(buffer)

#     print(f"Base64 decode time: {time.time() - start}")

#     cv2_start = time.time()

#     nparr = np.frombuffer(img, np.uint8)
#     image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
#     image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.

#     print(f"cv2 preprocessing time: {time.time() - cv2_start}")

#     start_model = time.time()
#     data = run_inference(image=image, load_model=False, sampler=resshift_sampler_, args=args_)
#     print(f"Model total inference time (s): {time.time() - start_model}")

#     encode_time = time.time()

#     plt.imshow(data)
#     plt.show()

#     _, buffer = cv2.imencode('.jpg', data)

#     encode_img = base64.b64encode(buffer).decode('utf-8')
    
#     print(f"Encode time: {time.time() - encode_time}")

#     print(f"ETA: {time.time() - start}")

#     return jsonify({'message': 'Image received successfully', 'deblurred_img': encode_img}), 200


@app.route('/run_inference', methods=['POST'])
def index():
    start_time = time.time()

    # Check if the request contains a file under the key "file"
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    # print(f"chkpt 1")
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400

    # print(f"read in file")

    try:
        # Open the image using PIL from the binary stream
        # image = Image.open(file.stream)
        # Now process the image (for example, run your inference/upscaling)
        # ...
        # Let's assume the processing returns a new PIL image called `processed_image`

        # image = np.array(image).astype(np.float32) / 255.

        file_bytes = np.asarray(bytearray(file.stream.read()), dtype=np.uint8)
        image = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)  # Reads image as BGR uint8
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)  # Convert to RGB
        image = image.astype(np.float32) / 255.0  # Normalize

        # print(f"img: {image}")
        # plt.imshow(image)
        # plt.show()

        # print(f"processing time: {time.time() - start_time}")

        start_model = time.time()
        data = run_inference(image=image, load_model=False, sampler=resshift_sampler_, args=args_)
        # print(f"Model total inference time (s): {time.time() - start_model}")

        # Optionally, convert the processed image to Base64 if you want to return it that way.
        # Here’s how you might do that:
        encode_time = time.time()
        _, buffer = cv2.imencode('.jpg', data)
        encode_img = base64.b64encode(buffer).decode('utf-8')
        
        # print(f"Encode time: {time.time() - encode_time}")

        print(f"ETA: {time.time() - start_time}")

        return jsonify({'message': 'Image received successfully', 'deblurred_img': encode_img}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # start = time.time()

    # img = request.get_json()
    # buffer = img['image']
    # # print(buffer)
    # img = base64.b64decode(buffer)

    # print(f"Base64 decode time: {time.time() - start}")

    # cv2_start = time.time()

    # nparr = np.frombuffer(img, np.uint8)
    # image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    # image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.

    # print(f"cv2 preprocessing time: {time.time() - cv2_start}")

    # encode_time = time.time()

    # plt.imshow(data)
    # plt.show()

    # _, buffer = cv2.imencode('.jpg', data)

    # encode_img = base64.b64encode(buffer).decode('utf-8')
    
    # print(f"Encode time: {time.time() - encode_time}")

    # print(f"ETA: {time.time() - start}")

    # return jsonify({'message': 'Image received successfully', 'deblurred_img': encode_img}), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
