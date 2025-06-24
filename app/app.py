from flask import Flask, request, render_template, jsonify, send_file
import tempfile
import boto3
from botocore.client import Config
from botocore.exceptions import EndpointConnectionError, NoCredentialsError
import os
import time
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
endpoint_url = os.getenv('CEPH_ENDPOINT', 'http://192.168.0.3:8080')
bucket_name = 'test'
access_key = os.getenv('AWS_ACCESS_KEY_ID', 'test')
secret_key = os.getenv('AWS_SECRET_ACCESS_KEY', 'test')

logger.info(f"Connecting to Ceph at: {endpoint_url}")

def create_s3_client():
    """Create S3 client with retry logic"""
    session = boto3.session.Session()
    return session.client(
        's3',
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(
            signature_version='s3v4',
            connect_timeout=10,
            read_timeout=10,
            retries={'max_attempts': 3}
        )
    )

def wait_for_ceph():
    """Wait for Ceph to be ready"""
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            s3_client = create_s3_client()
            # Try to list buckets to test connection
            s3_client.list_buckets()
            logger.info("Successfully connected to Ceph")
            return s3_client
        except Exception as e:
            retry_count += 1
            logger.warning(f"Attempt {retry_count}: Ceph not ready yet - {str(e)}")
            time.sleep(5)
    
    logger.error("Failed to connect to Ceph after maximum retries")
    return None

# Initialize S3 client
s3_client = wait_for_ceph()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/health')
def health():
    try:
        if s3_client:
            # Test connection
            s3_client.list_buckets()
            return jsonify({
                'status': 'healthy', 
                'message': 'Flask app is running and connected to Ceph',
                'endpoint': endpoint_url
            })
        else:
            return jsonify({
                'status': 'unhealthy', 
                'message': 'Flask app is running but not connected to Ceph',
                'endpoint': endpoint_url
            }), 503
    except Exception as e:
        return jsonify({
            'status': 'unhealthy', 
            'message': f'Error connecting to Ceph: {str(e)}',
            'endpoint': endpoint_url
        }), 503

@app.route('/upload', methods=['POST'])
def upload():
    global s3_client
    
    try:
        if not s3_client:
            logger.error("S3 client not initialized")
            return jsonify({'message': 'S3 service not available'}), 503
            
        file = request.files.get('file')
        if not file:
            return jsonify({'message': 'No file uploaded'}), 400
            
        logger.info(f"Uploading file: {file.filename}")
        
        # Ensure bucket exists
        try:
            s3_client.head_bucket(Bucket=bucket_name)
        except:
            logger.info(f"Creating bucket: {bucket_name}")
            s3_client.create_bucket(Bucket=bucket_name)
        
        # Upload file
        s3_client.upload_fileobj(file, bucket_name, file.filename)
        logger.info(f"Successfully uploaded: {file.filename}")
        
        return jsonify({'message': f'File {file.filename} uploaded successfully'})
        
    except EndpointConnectionError as e:
        logger.error(f"Endpoint connection error: {str(e)}")
        return jsonify({'message': f'Cannot connect to storage service: {str(e)}'}), 503
    except Exception as e:
        logger.error(f"Upload error: {str(e)}")
        return jsonify({'message': f'Upload failed: {str(e)}'}), 500

@app.route('/download/<filename>', methods=['GET'])
def download(filename):
    global s3_client
    
    try:
        if not s3_client:
            return jsonify({'message': 'S3 service not available'}), 503
            
        logger.info(f"Downloading file: {filename}")
        
        with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
            s3_client.download_file(bucket_name, filename, tmp_file.name)
            tmp_file.close()
            
            return send_file(tmp_file.name, as_attachment=True, download_name=filename)
            
    except EndpointConnectionError as e:
        logger.error(f"Endpoint connection error: {str(e)}")
        return jsonify({'message': f'Cannot connect to storage service: {str(e)}'}), 503
    except Exception as e:
        logger.error(f"Download error: {str(e)}")
        return jsonify({'message': f'Download failed: {str(e)}'}), 500

@app.route('/list')
def list_files():
    """List files in the bucket"""
    global s3_client
    
    try:
        if not s3_client:
            return jsonify({'message': 'S3 service not available'}), 503
            
        response = s3_client.list_objects_v2(Bucket=bucket_name)
        files = [obj['Key'] for obj in response.get('Contents', [])]
        
        return jsonify({'files': files})
        
    except Exception as e:
        logger.error(f"List error: {str(e)}")
        return jsonify({'message': f'List failed: {str(e)}'}), 500

if __name__ == '__main__':
    logger.info("Starting Flask app on 0.0.0.0:5000")
    app.run(debug=True, host='0.0.0.0', port=5000)
