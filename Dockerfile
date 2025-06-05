FROM pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime

# Set non-interactive frontend to avoid tzdata prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# Install linux packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc git zip unzip wget curl htop libgl1 libglib2.0-0 libpython3-dev \
    ffmpeg libsm6 libxext6 \
    && rm -rf /var/lib/apt/lists/*

# Security updates
RUN apt upgrade --no-install-recommends -y openssl tar

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY pyproject.toml .

# Install PyTorch3D and dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    pytorch3d \
    matplotlib \
    imageio \
    tqdm \
    numpy \
    argparse

# Install project dependencies from pyproject.toml
RUN pip install --no-cache-dir -e .

# Create output directory
RUN mkdir -p /app/output

# Copy source code
COPY src/ /app/src/
COPY . /app/

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Default command
ENTRYPOINT ["python", "/app/src/sphere_to_object.py"]
CMD ["-target", "target.obj"]