from flask import Flask, Response
import os

app = Flask(__name__)

@app.route("/")
def random():
    random_bytes = os.urandom(16)
    return Response(random_bytes, mimetype="application/octet-stream")