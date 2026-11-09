FROM python:3.14-slim

RUN pip install --no-cache-dir pytest==9.1.1 httpx==0.28.1

WORKDIR /tests
COPY . /tests

CMD ["pytest", "-q"]
