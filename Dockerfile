FROM python:latest

# Build argument for podcast name
ARG PODCAST_NAME
ENV PODCAST_NAME=${PODCAST_NAME}

# Validate that PODCAST_NAME is provided
RUN if [ -z "$PODCAST_NAME" ]; then \
        echo "ERROR: PODCAST_NAME build argument is required"; \
        echo "Usage: docker build --build-arg PODCAST_NAME=jk ."; \
        exit 1; \
    fi

# Set working directory
WORKDIR /app

# Copy and install Python dependencies first (for better caching)
# Each podcast may have different requirements
COPY scripts_${PODCAST_NAME}/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Install bash, vim, and other useful tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    vim \
    procps \
    less \
    curl \
    openssl \
    tzdata \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy general scripts (shared across all podcasts)
COPY shared/ ./shared/

# Copy podcast-specific scripts
COPY scripts_${PODCAST_NAME}/ ./scripts/

# Make sure all shell scripts are executable
RUN if [ -d "/app/shared" ]; then \
        find /app/shared -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true; \
    fi && \
    if [ -d "/app/scripts" ]; then \
        find /app/scripts -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true; \
    fi

# Create logs and feeds directories
RUN mkdir -p /app/logs /app/feeds

# Show build info
RUN echo "==================================" && \
    echo "Built for podcast: $PODCAST_NAME" && \
    echo "==================================" && \
    ls -la /app/scripts/ && \
    echo "==================================" && \
    ls -la /app/shared/ && \
    echo "=================================="

# Default to bash for interactive debugging
ENTRYPOINT ["bash"]