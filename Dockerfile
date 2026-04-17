FROM ubuntu

COPY isp-cert.crt /etc/ssl/certs/ca-certificates.crt

RUN sed -i 's|http://|https://|g' /etc/apt/sources.list.d/ubuntu.sources

RUN apt update && apt install -y python3 python3-venv

RUN python3 -m venv /venv && /venv/bin/pip install flask

WORKDIR /app
COPY . .

CMD ["/venv/bin/python3", "-m", "flask", "run", "--host=0.0.0.0"]