FROM python:3.14
COPY python-k8s/requirements.txt requirements.txt
RUN pip install -r requirements.txt