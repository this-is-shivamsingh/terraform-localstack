# Use official Python runtime as the base image
FROM python:3.9-slim

# Set working directory in the container
WORKDIR /app

# Copy the Python script to the container
COPY app.py .

# Install Flask
RUN pip install flask

# Expose port 5000
EXPOSE 5000

# Command to run the app
CMD ["python", "app.py"]