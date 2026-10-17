# Forever Speed aktarma sunucusu (tools/relay.py). Sunucuda: docker compose -f relay.compose.yml up -d --build
FROM python:3.13-alpine
COPY relay.py /app/relay.py
ENV PORT=47812 PYTHONUNBUFFERED=1
USER 65534:65534
CMD ["python3", "-I", "-S", "/app/relay.py"]
