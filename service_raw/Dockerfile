FROM python:3.13-slim

WORKDIR /service_raw

COPY ./requirements.txt .
RUN pip install -r ./requirements.txt

COPY /app .
COPY /alembic .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]