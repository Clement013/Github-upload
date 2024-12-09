from flask import Flask, request, jsonify
from transformers import AutomaticSpeechRecognitionPipeline, WhisperForConditionalGeneration, WhisperTokenizer, WhisperProcessor
from peft import PeftModel, PeftConfig
import torch
import os
from enum import Enum
from datetime import datetime
import random
import logging

logging.basicConfig(filename='app.log', level=logging.ERROR)
app = Flask(__name__)

class SpeechRecognizer:
    def __init__(self, peft_model_id, language="malay", task="transcribe"):
        self.language = language
        self.task = task
        self.peft_model_id = peft_model_id
        peft_config = PeftConfig.from_pretrained(self.peft_model_id)

        self.model = WhisperForConditionalGeneration.from_pretrained(
            peft_config.base_model_name_or_path, load_in_8bit=True, device_map="auto"
        )
        self.model = PeftModel.from_pretrained(self.model, self.peft_model_id)
        self.tokenizer = WhisperTokenizer.from_pretrained(peft_config.base_model_name_or_path, language=self.language, task=self.task)
        self.processor = WhisperProcessor.from_pretrained(peft_config.base_model_name_or_path, language=self.language, task=self.task)
        self.feature_extractor = self.processor.feature_extractor
        self.forced_decoder_ids = self.processor.get_decoder_prompt_ids(language=self.language, task=self.task)

        self.pipe = AutomaticSpeechRecognitionPipeline(
            model=self.model, tokenizer=self.tokenizer, feature_extractor=self.feature_extractor
        )

    def transcribe(self, audio_file):
        if torch.cuda.is_available():
            with torch.cuda.amp.autocast():
                result = self.pipe(audio_file, generate_kwargs={"forced_decoder_ids": self.forced_decoder_ids}, max_new_tokens=255)
        else:
            result = self.pipe(audio_file, generate_kwargs={"forced_decoder_ids": self.forced_decoder_ids}, max_new_tokens=255)
        return result["text"]

# Define an enumeration for response statuses
class StatusEnum(Enum):
    SUCCESS = 1
    FAILED = 2
    ERROR = 3

def create_response(status, message, data=None):
    """Helper function to create a standardized response."""
    return {
        'Status': status.value,
        'Message': message,
        'Data': data
    }

recognizer = SpeechRecognizer(peft_model_id="clt013/whisper-large-v3-ft-malay-peft-epoch-20")

@app.route('/', methods=['GET'])
def test():
    return 'Server is running'

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    # Define the secret token
    SECRET_TOKEN = os.getenv("SECRET_TOKEN")

    # Check if the audio file is present and if the secret token matches
    if 'audio' not in request.files or request.form.get('secret') != SECRET_TOKEN:
        return jsonify(create_response(StatusEnum.ERROR, 'Unauthorized access or no audio file provided')), 403

    # Get the audio file
    audio_file = request.files['audio']
    # random file name + timestamp
    timpestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    temp_path = f"temp_audio_{timpestamp}_{str(random.randint(1000,9999))}.wav"
    audio_file.save(temp_path)

    try:
        # Transcribe the audio
        # calculate the transcription time
        time_start = datetime.now()
        print("Transcribing audio file...")
        transcription = recognizer.transcribe(temp_path)
        time_end = datetime.now()
        time_diff = time_end - time_start
        print(f"Transcription took {time_diff.total_seconds()} seconds")

        return jsonify(create_response(
            StatusEnum.SUCCESS, 
            'Transcription successful', 
            transcription))

    except Exception as e:
        logging.error(f"Transcription error: {e}")
        return jsonify(create_response(StatusEnum.FAILED, str(e)))
    
    finally:
        # Clean up the temporary file
        if os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
