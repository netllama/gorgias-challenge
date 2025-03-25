# Use the official Python image as the base image
FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container
COPY ./todo /app

# Expose port 5000 for the Gunicorn server
EXPOSE 5000

# Run the Flask app using Gunicorn
CMD exec gunicorn --bind :5000 --workers 1 --threads 8 app:app
