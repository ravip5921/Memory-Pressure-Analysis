FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    python3 \
    apache2-utils \
    stress-ng \
    procps \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY workloads/ /app/

EXPOSE 8080

CMD ["python3", "latency_server.py"]