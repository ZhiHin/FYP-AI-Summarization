from fastapi import FastAPI, HTTPException, File, UploadFile
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoModel, AutoTokenizer, pipeline
from PIL import Image
import requests
from io import BytesIO
import torch
import logging
import fitz  # PyMuPDF
import re
import os
import time
from enum import Enum

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI()

# Enable CORS for all routes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load the pre-trained OCR model and tokenizer
tokenizer = AutoTokenizer.from_pretrained('ucaslcl/GOT-OCR2_0', trust_remote_code=True)
model = AutoModel.from_pretrained('ucaslcl/GOT-OCR2_0', trust_remote_code=True, low_cpu_mem_usage=True, device_map='cuda', use_safetensors=True, pad_token_id=tokenizer.eos_token_id)
model = model.eval().cuda()

# Initialize the abstractive summarization pipeline (FLAN-T5)
try:
    summarizer = pipeline(
        "text2text-generation", 
        model="spacemanidol/flan-t5-large-website-summarizer",
        device=-1  # Use CPU by default for compatibility
    )
    logger.info("Summarization model (FLAN-T5) loaded successfully")
except Exception as e:
    logger.error(f"Error loading FLAN-T5 model: {e}")
    summarizer = None

# Initialize the extractive summarization pipeline (BART)
extractive_summarizer = pipeline("summarization", model="facebook/bart-large-cnn")

class OCRRequest(BaseModel):
    image_url: str

class SummarizationType(str, Enum):
    abstractive = "abstractive"
    extractive = "extractive"

class SummarizeRequest(BaseModel):
    text: str
    max_length: int = 150
    summary_type: SummarizationType

# Text cleaning function
def clean_text(text: str) -> str:
    """Clean and preprocess the text."""
    text = re.sub(r'\s+', ' ', text)  # Remove extra whitespace and newlines
    text = re.sub(r'[^\w\s.,?!]', '', text)  # Remove special characters
    return text.strip()

# Dynamic length calculation for flexible summary lengths
def calculate_dynamic_max_length(text_length: int, min_length: int = 50, max_length: int = 300) -> int:
    """Calculate a flexible max_length based on the input text length."""
    return int(min(max(text_length * 0.1, min_length), max_length))

# Chunking function for large text
def chunk_text(text: str, chunk_size: int = 1000) -> list:
    """Split text into chunks of approximately chunk_size words."""
    words = text.split()
    chunks = []
    current_chunk = []
    current_length = 0

    for word in words:
        current_length += 1
        current_chunk.append(word)
        
        if current_length >= chunk_size:
            chunks.append(' '.join(current_chunk))
            current_chunk = []
            current_length = 0
    
    if current_chunk:
        chunks.append(' '.join(current_chunk))
    
    return chunks

# Function to summarize large text by chunking
def summarize_large_text(text: str, max_length: int = 150) -> str:
    """Summarize large text by chunking and combining summaries."""
    try:
        chunks = chunk_text(text)
        summaries = []

        for chunk in chunks:
            if len(chunk.strip()) > 50:
                chunk_summary = summarizer(
                    f"summarize: {chunk}",
                    max_length=max_length,
                    num_beams=4,
                    early_stopping=True,
                    temperature=0.7,
                    do_sample=True
                )
                summaries.append(chunk_summary[0]['generated_text'])

        final_summary = " ".join(summaries)

        if len(final_summary.split()) > max_length:
            final_summary = summarizer(
                f"summarize: {final_summary}",
                max_length=max_length,
                num_beams=4,
                early_stopping=True,
                temperature=0.7,
                do_sample=True
            )[0]['generated_text']

        return final_summary

    except Exception as e:
        logger.error(f"Error in summarization: {e}")
        return None

# Function for extractive summarization using BART with chunking
def extractive_summarization(text: str, max_chunk_length: int = 1024) -> str:
    """Extractive summarization for text using BART model with chunking."""
    try:
        chunks = chunk_text(text, chunk_size=max_chunk_length)
        summaries = []

        for chunk in chunks:
            summary = extractive_summarizer(chunk, max_length=150, min_length=50, do_sample=False)
            summaries.append(summary[0]['summary_text'])

        return " ".join(summaries)

    except Exception as e:
        logger.error(f"Error in extractive summarization: {e}")
        return None

# Structure the summary
def structure_summary(summary: str) -> str:
    sentences = summary.split('.')
    structured_summary = ""
    section_counter = 1

    for sentence in sentences:
        if len(sentence.split()) > 5:
            structured_summary += f"\n\n**Section {section_counter}:**\n- {sentence.strip()}."
            section_counter += 1

    if not structured_summary:
        structured_summary = f"\n- {summary.strip()}"

    return structured_summary

# OCR Endpoint
@app.post("/ocr")
async def perform_ocr(request: OCRRequest):
    try:
        logging.info(f"Processing image from URL: {request.image_url}")
        res = model.chat(tokenizer, request.image_url, ocr_type='ocr')
        logging.info(f"OCR result: {res}")
        return {"generated_text": res}
    except Exception as e:
        logging.error(f"Error processing image: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# PDF Text Extraction Endpoint
@app.post("/extract_text")
async def extract_text(file: UploadFile = File(...)):
    """Extract text from uploaded PDF file."""
    start_time = time.time()
    
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    pdf_text = ""
    try:
        with fitz.open(stream=await file.read(), filetype="pdf") as pdf_document:
            for page in pdf_document:
                pdf_text += page.get_text()
    except Exception as e:
        logger.error(f"Error reading PDF: {e}")
        raise HTTPException(status_code=400, detail="Invalid or corrupted PDF file")

    pdf_text = clean_text(pdf_text)
    
    if not pdf_text:
        raise HTTPException(status_code=400, detail="No text could be extracted from the PDF")

    processing_time = time.time() - start_time
    logger.info(f"PDF processing time: {processing_time:.2f} seconds")

    return JSONResponse(content={
        "text": pdf_text,
        "processing_time": processing_time
    })

# Summarization Endpoint
@app.post("/summarize")
async def summarize_text(request: SummarizeRequest):
    """Summarize text using FLAN-T5 model or extractive model with flexible length and structured display."""
    logger.info(f"Received summarization request with type: {request.summary_type}")
    logger.info(f"Text length: {len(request.text)}")
    
    start_time = time.time()
    text = clean_text(request.text)
    text_length = len(text.split())
    max_length = calculate_dynamic_max_length(text_length, min_length=50, max_length=request.max_length)

    if not text:
        raise HTTPException(status_code=400, detail="Empty text after cleaning")

    if request.summary_type == SummarizationType.abstractive:
        logger.info("Processing as abstractive summarization.")
        # For abstractive summarization using FLAN-T5
        if not summarizer:
            raise HTTPException(status_code=503, detail="Summarization model not available")

        if text_length > 1000:
            # For larger texts, chunk and summarize
            summary = summarize_large_text(text, max_length)
        else:
            # For smaller texts, use the FLAN-T5 summarizer
            summary = summarizer(
                f"summarize: {text}",
                max_length=max_length,
                num_beams=4,
                early_stopping=True,
                temperature=0.7,
                do_sample=True
            )[0]['generated_text']
        summary = structure_summary(summary)

        # Mark it as abstractive in the output
        summary = f"**Abstractive Summary:**\n{summary}"

    elif request.summary_type == SummarizationType.extractive:
        logger.info("Processing as extractive summarization.")
        # For extractive summarization using BART
        summary = extractive_summarization(text)

        # Mark it as extractive in the output
        summary = f"**Extractive Summary:**\n{summary}"

    if not summary:
        raise HTTPException(status_code=500, detail="Failed to generate summary")

    processing_time = time.time() - start_time
    logger.info(f"Summarization time: {processing_time:.2f} seconds")

    return JSONResponse(content={
        "summary": summary,
        "processing_time": processing_time
    })

# Health Check Endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return JSONResponse(content={
        "status": "healthy",
        "model_loaded": summarizer is not None,
        "version": "1.0.0"
    })

# Run the server (optional, used if script is run directly)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)