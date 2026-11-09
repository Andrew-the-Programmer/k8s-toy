FROM python:3.14-slim

WORKDIR /app
COPY --chown=65534:65534 app.py .

USER 65534
EXPOSE 8080

CMD ["python", "app.py"]
