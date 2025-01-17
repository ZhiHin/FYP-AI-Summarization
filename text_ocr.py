from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModel, AutoTokenizer
from PIL import Image
import requests
from io import BytesIO
import torch
import logging

app = FastAPI()

# Configure logging
logging.basicConfig(level=logging.INFO)

# Load the pre-trained model and tokenizer
tokenizer = AutoTokenizer.from_pretrained('ucaslcl/GOT-OCR2_0', trust_remote_code=True)
model = AutoModel.from_pretrained('ucaslcl/GOT-OCR2_0', trust_remote_code=True, low_cpu_mem_usage=True, device_map='cuda', use_safetensors=True, pad_token_id=tokenizer.eos_token_id)
model = model.eval().cuda()

class OCRRequest(BaseModel):
    image_url: str

@app.post("/ocr")
async def perform_ocr(request: OCRRequest):
    try:
        logging.info(f"Processing image from URL: {request.image_url}")
        res = model.chat_crop(tokenizer, request.image_url, ocr_type='format')
        logging.info(f"OCR result: {res}")
        return {"generated_text": res}
    except Exception as e:
        logging.error(f"Error processing image: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)