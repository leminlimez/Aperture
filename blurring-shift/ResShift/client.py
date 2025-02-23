import base64
import requests

filename = '../test_blur2.jpg'

with open(filename, "rb") as img:
    string = base64.b64encode(img.read()).decode('utf-8')

api_url = 'http://127.0.0.1:5000/run_inference'
response = requests.post(api_url, json={'user_photo': string})

print(response.json())