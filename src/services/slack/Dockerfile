FROM python:3.11-slim
WORKDIR /app

RUN pip install --no-cache-dir prometheus_client

COPY server.py ./
COPY . .

EXPOSE 8080
CMD ["python3", "server.py"]
