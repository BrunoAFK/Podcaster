# Requested tag: Python 3.12.13 on Alpine 3.23
# Verified runtime from provided digest currently resolves to Python 3.13.12.
FROM python:3.12.13-alpine3.23@sha256:bb1f2fdb1065c85468775c9d680dcd344f6442a2d1181ef7916b60a623f11d40 AS builder

# Build argument for podcast name
ARG PODCAST_NAME
ENV PODCAST_NAME=${PODCAST_NAME}
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# Validate that PODCAST_NAME is provided
RUN if [ -z "$PODCAST_NAME" ]; then \
        echo "ERROR: PODCAST_NAME build argument is required"; \
        echo "Usage: docker build --build-arg PODCAST_NAME=jk ."; \
        exit 1; \
    fi

WORKDIR /app

# Install Python dependencies into a dedicated virtualenv so the runtime stage
# only needs the packages required to execute the scraper.
COPY scripts_${PODCAST_NAME}/requirements.txt ./
RUN python -m venv "${VIRTUAL_ENV}" && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Requested tag: Python 3.12.13 on Alpine 3.23
# Verified runtime from provided digest currently resolves to Python 3.13.12.
FROM python:3.12.13-alpine3.23@sha256:bb1f2fdb1065c85468775c9d680dcd344f6442a2d1181ef7916b60a623f11d40

ARG PODCAST_NAME
ENV PODCAST_NAME=${PODCAST_NAME}
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

WORKDIR /app

# Minimal runtime packages:
# - bash: existing runner scripts rely on bash features
# - curl: Telegram notifications
# - tzdata: Europe/Zagreb timezone data
RUN apk add --no-cache bash curl tzdata

COPY --from=builder /opt/venv /opt/venv

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
    fi && \
    mkdir -p /app/logs /app/feeds

ENTRYPOINT ["bash"]
