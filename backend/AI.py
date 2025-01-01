import json
import string
import tempfile
from fastapi import FastAPI, HTTPException, File, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pkg_resources import resource_filename
from pydantic import BaseModel
import spacy
from transformers import AutoModel, AutoTokenizer, pipeline, AutoModelForSeq2SeqLM
from PIL import Image, ImageFilter, ImageOps
import requests
from io import BytesIO
import torch
import logging
import fitz  # PyMuPDF
import re
import os
import time
from enum import Enum
from symspellpy.symspellpy import SymSpell
import spacy
from happytransformer import HappyTextToText, TTSettings
import cv2
import numpy as np
from google.cloud import vision
from google.cloud import speech
from pydub import AudioSegment
from pydub import AudioSegment
from pydub.utils import make_chunks
import io
import asyncio

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI()
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "service_account_token.json"
client = vision.ImageAnnotatorClient()
speech_client = speech.SpeechClient()

# Enable CORS for all routes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
try:
    extractive_summarizer = pipeline(
        "summarization", 
        model="facebook/bart-large-cnn",
        device=-1  # Use CPU by default for compatibility
    )
    logger.info("Extractive Summarization model (bart) loaded successfully")
except Exception as e:
    logger.error(f"Error loading BART model: {e}")
    summarizer = None

try:
    asr_pipe = pipeline("automatic-speech-recognition", model="AqeelShafy7/AudioSangraha-Audio_to_Text")
    print("ASR model loaded successfully.")
except Exception as e:
    print(f"Error loading ASR model: {e}")
    asr_pipe = None

class OCRRequest(BaseModel):
    image_url: str
    option: str 
    
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

# Initialize the tokenizer for chunking
try:
    tokenizer = AutoTokenizer.from_pretrained("spacemanidol/flan-t5-large-website-summarizer", legacy=False)
    logger.info("Tokenizer for chunking loaded successfully")
except Exception as e:
    logger.error(f"Error loading tokenizer for chunking: {e}")
    tokenizer = None

# Chunking function for large text
def chunk_text(text: str, chunk_size: int = 1000) -> list:
    if not tokenizer:
        raise ValueError("Tokenizer is not loaded")

    words = text.split()
    chunks = []
    current_chunk = []
    current_length = 0

    for word in words:
        current_chunk.append(word)
        # Check token length using tokenizer
        tokenized_chunk = tokenizer.encode(' '.join(current_chunk), truncation=True)
        if len(tokenized_chunk) > chunk_size:
            chunks.append(' '.join(current_chunk[:-1]))  # Add the previous chunk if the current one exceeds limit
            current_chunk = [word]  # Start new chunk
        else:
            current_length += 1
     
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
def extractive_summarization(
    text: str, max_summary_length: int = 150, min_summary_length: int = 50
) -> str:
    try:
        if not text or not text.strip():
            return "No valid text provided for summarization."

        if not extractive_summarizer:
            return "Summarization model is not loaded. Please check the model configuration."

        # Split the text into chunks
        chunks = chunk_text(text)
        logging.info(f"Split text into {len(chunks)} chunks.")

        summaries = []
        for chunk in chunks:
            if not chunk.strip():
                logging.warning("Skipping empty chunk.")
                continue  # Skip empty chunks

            try:
                # Perform summarization on each chunk
                summary = extractive_summarizer(
                    chunk,
                    max_length=max_summary_length,
                    min_length=min_summary_length,
                    truncation=True
                )[0]['summary_text']
                summaries.append(summary)
            except Exception as chunk_error:
                logging.warning(f"Error summarizing chunk: {chunk_error}")

        if not summaries:
            return "Unable to generate a summary from the input text."

        # Combine all summaries into a cohesive output
        return "\n".join(summaries).strip()

    except Exception as e:
        logging.error(f"Unexpected error during summarization: {e}")
        return "An unexpected error occurred during summarization."

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
def process_ocr_output(text):
    text = text.strip()
    
    # Remove multiple spaces
    text = re.sub(r'\s+', ' ', text)
    
    # Remove tabs and extra spaces
    text = re.sub(r'[ \t]+', ' ', text).strip()
    
    # Add space after commas if not present
    text = re.sub(r'([,])(\S)', r'\1 \2', text)
    
    # Add new line after every special character except for commas
    text = re.sub(r'([.!?;:])', r'\1\n', text)
    
    # Remove space if character before is a newline
    text = re.sub(r'\n\s+', '\n', text)
    
    return text

@app.post("/format")
async def perform_ocr(image: UploadFile = File(...)):
    try:
        temp_dir = "temp_images"
        os.makedirs(temp_dir, exist_ok=True)
        
        file_location = f"{temp_dir}/{image.filename}"
    
        with open(file_location, "wb+") as file_object:
            file_object.write(await image.read())

        # Load the image into memory
        with open(file_location, "rb") as image_file:
            content = image_file.read()

        image = vision.Image(content=content)
        response = client.document_text_detection(image=image)
        text = response.text_annotations[0].description
        text = process_ocr_output(text)
        
        for page in response.full_text_annotation.pages:
            for block in page.blocks:
                print('\nBlock confidence: {}\n'.format(block.confidence))

                for paragraph in block.paragraphs:
                    print('Paragraph confidence: {}'.format(
                        paragraph.confidence))

                    for word in paragraph.words:
                        word_text = ''.join([
                            symbol.text for symbol in word.symbols
                        ])
                        print('Word text: {} (confidence: {})'.format(
                            word_text, word.confidence))

                        for symbol in word.symbols:
                            print('\tSymbol: {} (confidence: {})'.format(
                                symbol.text, symbol.confidence))
        # Clean up
        os.remove(file_location)

        return {"extracted_text": text}
    except Exception as e:
        logging.error(f"Error processing image: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    
@app.post("/extract_main_points")
async def extract_main_points(request: SummarizeRequest):
    try:
        text = "extract main points" + request.text
        main_points = extractive_summarizer(text, max_length = request.max_length, min_length = 50)
        return {"extracted_text": main_points}
    except Exception as e:
        logging.error(f"Error extracting main points: {e}")
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

@app.post("/audio_to_text")
async def audio_to_text(file: UploadFile = File(...)):
    """Transcribes audio files into text using Google Speech-to-Text API."""
    try:
        print(f"Debug: Received file: {file.filename}")

        # Validate file format
        allowed_formats = ('.wav', '.mp3', '.flac', '.m4a')
        if not file.filename.lower().endswith(allowed_formats):
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file format. Supported formats: {allowed_formats}"
            )

        # Save uploaded file
        temp_path = "temp_audio/audio.mp3"  # Keep it as mp3 for the test
        contents = await file.read()
        with open(temp_path, "wb") as temp_file:
            temp_file.write(contents)
        print(f"Debug: File saved to {temp_path}")

        # Open the audio file
        with open(temp_path, "rb") as audio_file:
            content = audio_file.read()

        # Configure audio file for speech recognition
        audio = speech.RecognitionAudio(content=content)
        
        # Adjust configuration based on the format
        if file.filename.lower().endswith('.mp3'):
            encoding = speech.RecognitionConfig.AudioEncoding.MP3
        elif file.filename.lower().endswith('.flac'):
            encoding = speech.RecognitionConfig.AudioEncoding.FLAC
        else:
            encoding = speech.RecognitionConfig.AudioEncoding.LINEAR16  # Default for WAV

        # Sample rate for MP3, WAV or FLAC files can differ, so set it based on the file type
        sample_rate_hertz = 16000  # Default sample rate for most speech-to-text

        config = speech.RecognitionConfig(
            encoding=encoding,
            sample_rate_hertz=sample_rate_hertz,
            language_code="en-US",
            enable_automatic_punctuation=True,
            use_enhanced=True,
        )

        # Request transcription via streaming
        streaming_config = speech.StreamingRecognitionConfig(config=config)
        requests = [speech.StreamingRecognizeRequest(audio_content=content)]

        responses = speech_client.streaming_recognize(streaming_config, requests)

        # Collect transcription
        transcription = ""
        for response in responses:
            if response.results:
                for result in response.results:
                    print(f"Debug: Transcription segment: {result.alternatives[0].transcript}")
                    transcription += result.alternatives[0].transcript
            else:
                print("Debug: No results found in this response.")

        if transcription:
            print(f"Debug: Transcription successful: {transcription[:100]}...")  # Output first 100 characters
        else:
            print("Debug: No transcription text was generated.")

        return {"transcription": transcription if transcription else "No transcription available"}

    except Exception as e:
        print(f"Debug: Error in audio_to_text: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    

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