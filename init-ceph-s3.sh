#!/bin/bash

echo "🚀 Initializing Ceph S3 Demo Environment"
echo "========================================"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command_exists docker; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker-compose; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Prerequisites satisfied"

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down -v 2>/dev/null || true

# Clean up any orphaned containers
echo "🧹 Cleaning up..."
docker container prune -f
docker volume prune -f

# Build and start services
echo "🏗️  Building and starting services..."
docker-compose up --build -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local url=$2
    local max_attempts=60
    local attempt=1
    
    echo "Waiting for $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts: $service_name not ready yet..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "❌ $service_name failed to start within expected time"
    return 1
}

# Wait for Ceph S3 Gateway
wait_for_service "Ceph S3 Gateway" "http://localhost:8080"

# Wait for Flask App
wait_for_service "Flask Application" "http://localhost:5000/health"

# Test S3 functionality
echo "🧪 Testing S3 functionality..."

# Install AWS CLI if not present
if ! command_exists aws; then
    echo "Installing AWS CLI..."
    if command_exists pip3; then
        pip3 install awscli
    elif command_exists pip; then
        pip install awscli
    else
        echo "⚠️  AWS CLI not available. Please install manually to test S3 commands."
    fi
fi

if command_exists aws; then
    # Configure AWS CLI for local Ceph
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    
    echo "Creating test bucket..."
    aws s3 mb s3://test --endpoint-url http://localhost:8080 2>/dev/null || echo "Bucket may already exist"
    
    echo "Testing file upload..."
    echo "Hello from Ceph S3!" > test-file.txt
    aws s3 cp test-file.txt s3://test/ --endpoint-url http://localhost:8080
    
    echo "Listing bucket contents..."
    aws s3 ls s3://test --endpoint-url http://localhost:8080
    
    # Clean up test file
    rm -f test-file.txt
fi

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Services are running:"
echo "• Ceph S3 Gateway: http://localhost:8080"
echo "• Flask Web UI: http://localhost:5000"
echo ""
echo "S3 Access:"
echo "• Endpoint: http://localhost:8080"
echo "• Access Key: test"
echo "• Secret Key: test"
echo "• Bucket: test"
echo ""
echo "Useful commands:"
echo "• View logs: docker-compose logs -f"
echo "• Stop services: docker-compose down"
echo "• Restart: docker-compose restart"
echo "• Check status: docker-compose ps"
echo ""
echo "Open http://localhost:5000 in your browser to use the web interface!"