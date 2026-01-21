FROM python:3.10-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache --update \
    bash \
    curl \
    docker-cli \
    mariadb-client \
    && rm -rf /var/cache/apk/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Run the backup service
CMD ["python", "main.py"]
