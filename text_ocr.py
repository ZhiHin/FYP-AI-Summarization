from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModel, AutoTokenizer
from PIL import Image
import requests
from io import BytesIO
import torch

app = FastAPI()

# Load the pre-trained model and tokenizer
tokenizer = AutoTokenizer.from_pretrained('ucaslcl/GOT-OCR2_0', trust_remote_code=True)
model = AutoModel.from_pretrained('ucaslcl/GOT-OCR2_0', trust_remote_code=True, low_cpu_mem_usage=True, device_map='cuda', use_safetensors=True, pad_token_id=tokenizer.eos_token_id)
model = model.eval().cuda()

class OCRRequest(BaseModel):
    image_url: str

def preprocess_image(image_url):
    response = requests.get(image_url)
    image = Image.open(BytesIO(response.content)).convert("RGB")
    return image

@app.post("/ocr")
async def perform_ocr(request: OCRRequest):
    try:
        image = preprocess_image(request.image_url)

        res = model.chat(tokenizer, image, ocr_type='ocr')
        return {"generated_text": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)