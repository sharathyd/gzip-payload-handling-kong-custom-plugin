# app.py
from flask import Flask, request
app = Flask(__name__)

@app.route("/upload", methods=["POST"])
def upload():
    with open("received.gz", "wb") as f:
        f.write(request.data)
        print("Received payload content - ", request.data)
    return "Payload request received - OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=4040)

