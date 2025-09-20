FROM python:3.13

ADD ./pve_conf_server /app
RUN pip install -r /app/requirements.txt

WORKDIR /app

CMD [ "python", "server.py" ]
