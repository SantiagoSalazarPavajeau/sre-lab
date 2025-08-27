FROM python:3.11-slim
WORKDIR /app

# install prometheus client for metrics endpoint
RUN pip install --no-cache-dir prometheus_client

# copy application files and the server entrypoint
COPY server.py ./
COPY . .

EXPOSE 8080
CMD ["python3", "server.py"]