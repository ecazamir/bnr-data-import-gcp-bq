# Use an official lightweight Python image
FROM python:3.14-slim

# Set the working directory in the container
WORKDIR /app

# Copy the dependencies file
COPY src/requirements.txt .

# Install necessary libraries without keeping cache (space saving)
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code from local src/ folder to container
COPY src/ .

# Container start command
CMD ["python", "main.py"]
