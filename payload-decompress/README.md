
# 📦 Kong Gateway – Gzip Payload Handling with Custom Plugin

This project demonstrates how to:

1. Create a gzip file as input payload.  
2. Run a Python HTTP server as upstream that writes incoming payloads to a file.  
3. Configure Kong Gateway service and route to forward requests.  
4. Test **gzip payload passthrough** (payload sent as-is to upstream).  
5. Build and enable a **custom Kong plugin** to decompress gzip payloads before sending upstream.  
6.  Run tests with both positive and negative scenarios.

---

## 🚀 Prerequisites

- Kong Gateway (Enterprise/OSS 3.10.x)  
- Docker & Docker Compose  
- Python 3.x  
- `curl`, `gzip`, `gunzip`, `md5sum`, `cmp`

---

## 1️⃣ Prepare a Gzip File

```bash
echo 'This is the payload sent via Kong Gateway.' > test.txt
gzip -c test.txt > test.txt.gz
````

---

## 2️⃣ Python Upstream Server

We’ll create a simple Flask HTTP server that receives payloads and writes them to a file.

**`app.py`**

```python
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
```

### Setup & Run

```bash
# Create venv
python3 -m venv venv
source venv/bin/activate

# Install Flask
pip install flask

# Start the server
python3 app.py
```

**Server Output**

```
 * Serving Flask app 'app'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:4040
 * Running on http://192.168.1.4:4040
Press CTRL+C to quit
```

---

## 3️⃣ Create Kong Service & Route

```bash
curl -i -X POST http://localhost:8001/services \
  --data name=gzip-payload-svc \
  --data url=http://192.168.1.4:4040/upload

curl -i -X POST http://localhost:8001/services/gzip-payload-svc/routes \
  --data name=gzip-payload-demo \
  --data paths[]=/gzip-payload-demo
```

---

## 4️⃣ Test Service Without Plugin (Send As-Is)

```bash
curl -X POST http://localhost:8000/gzip-payload-demo \
     -H "Content-Type: application/gzip" \
     --data-binary @test.txt.gz
```

**Client Output**

```
Payload request received - OK%
```

**Server Output**

```
192.168.1.4 - - [30/Sep/2025 09:53:26] "POST /upload HTTP/1.1" 200 -
```

Verify:

```bash
cmp test.txt.gz received.gz
md5sum test.txt.gz received.gz
```

✅ Both checksums match.

```bash
gunzip -d received.gz
cat received
# Output: This is the payload sent via Kong Gateway.
```

---

## 5️⃣ Build Custom Kong Image with Gzip Decompression Plugin

Download dependency:

```bash
wget https://github.com/hamishforbes/lua-ffi-zlib/raw/master/lua-ffi-zlib-0.6-0.rockspec
```

**`Dockerfile`**

```dockerfile
FROM kong/kong-gateway:3.10.0.2

USER root
COPY lua-ffi-zlib-0.6-0.rockspec /tmp/
RUN luarocks install /tmp/lua-ffi-zlib-0.6-0.rockspec

COPY custom-gzip-decompress-ffi /usr/local/share/lua/5.1/kong/plugins/custom-gzip-decompress-ffi
ENV KONG_PLUGINS=bundled,custom-gzip-decompress-ffi

USER kong
ENTRYPOINT ["/entrypoint.sh"]
CMD ["kong", "docker-start"]
```

Build image:

```bash
docker build -t kong-gw-custom-gzipplugin:3.10.0.2 .
docker image ls | grep custom
```

---

## 6️⃣ Enable Custom Plugin

```bash
curl -X POST http://localhost:8001/services/gzip-payload-svc/plugins \
  -H "Content-Type: application/json" \
  --data '{"name":"custom-gzip-decompress-ffi","config":{}}'
```

Response:

```json
{"enabled":true,"name":"custom-gzip-decompress-ffi", ...}
```

---

## 7️⃣ Test With Plugin (Auto-Decompression)

```bash
curl -X POST http://localhost:8000/gzip-payload-demo \
     -H "Content-Type: application/gzip" \
     -H "Content-Encoding: gzip" \
     --data-binary @test.txt.gz
```

**Client Output**

```
Payload request received - OK%
```

**Server Output**

```
Received payload content -  b'This is the payload sent via Kong Gateway.'
192.168.1.4 - - [30/Sep/2025 13:14:06] "POST /upload HTTP/1.1" 200 -
```

Verify:

```bash
file received.gz
# received.gz: ASCII text
cat received.gz
# This is the payload sent via Kong Gateway.
```

---

## 8️⃣ Negative Test Cases

### a) Missing `Content-Type`

```bash
curl -X POST http://localhost:8000/gzip-payload-demo \
     -H "Content-Encoding: gzip" \
     --data-binary @test.txt.gz
```

Server:

```
Received payload content -  b''
192.168.1.4 - - [30/Sep/2025 14:37:22] "POST /upload HTTP/1.1" 200 -
```

---

### b) Missing `Content-Encoding`

```bash
curl -X POST http://localhost:8000/gzip-payload-demo \
     -H "Content-Type: application/gzip" \
     --data-binary @test.txt.gz
```

Server:

```
Received payload content -  b'\x1f\x8b\x08\x08nN\xdbh...'
192.168.1.4 - - [30/Sep/2025 14:33:34] "POST /upload HTTP/1.1" 200 -
```

---

### c) Sending JSON Instead of Gzip

```bash
curl -X POST http://localhost:8000/gzip-payload-demo \
     -H "Content-Type: application/gzip" \
     --data '{ "payload":"hello kong, welcome to India" }'
```

Server:

```
Received payload content -  b'{ payload:hello kong, welcome to India }'
192.168.1.4 - - [30/Sep/2025 14:31:19] "POST /upload HTTP/1.1" 200 -
```

---
# ✅ Reference 
https://github.com/hamishforbes/lua-ffi-zlib/blob/master/README.md

---

# ✅ Conclusion

* Kong forwards gzip payloads **as-is** without a plugin.
* With the **custom plugin**, gzip payloads are **decompressed** before being sent upstream.
* Behavior validated with positive and negative test cases.



