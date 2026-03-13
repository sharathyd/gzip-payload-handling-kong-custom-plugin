
# How to Install Kong GO Custom Plugin

This repository demonstrates how to create, build, and run a **Kong Gateway Docker container** with a **custom Go plugin** (`go-hello`). It covers the entire process: writing the Dockerfile, building the image, running the container, applying configuration, and validating the custom plugin.

---

## 📦 Prerequisites

- Docker installed
- `curl`, `jq`, and `yq` installed (for testing and validation)
- Internet access for downloading dependencies

---

## 🛠️ Dockerfile

```dockerfile
FROM golang:alpine AS builder

RUN apk add --no-cache git gcc libc-dev curl 
RUN mkdir /go-plugins
RUN curl https://raw.githubusercontent.com/Kong/go-pdk/refs/heads/master/examples/go-hello.go -o /go-plugins/go-hello.go

RUN cd /go-plugins && \
    go mod init kong-go-plugin && \
    go get github.com/Kong/go-pdk && \
    go mod tidy && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build go-hello.go

FROM kong/kong-gateway:3.10.0.3

USER root

COPY --from=builder /go-plugins/go-hello /usr/local/bin/
RUN chmod +x /usr/local/bin/go-hello

USER kong
````

### 🔍 Notes

* go-hello.go is sample go custom plugin file 
* `CGO_ENABLED=0` makes the binary static (no `glibc` or `musl` dependencies).
* `GOOS=linux GOARCH=amd64` builds the binary for Linux x86\_64.

---

## 🏗️ Build the Docker Image

```bash
docker build --no-cache -t kong-custom-go .
```

### ✅ Docker Build Output (Excerpt)

```
[+] Building 30.1s (14/14) FINISHED
...
 => => exporting manifest sha256:8a1c4945...
 => => naming to docker.io/library/kong-custom-go:latest
```

---

## 🚀 Run the Kong Container

```bash
docker run --rm -d --name kong-custom-go \
  -p "8000-8002:8000-8002" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -e "KONG_PROXY_LISTEN=0.0.0.0:8000" \
  -e "KONG_DATABASE=off" \
  -e "KONG_PLUGINS=bundled,go-hello" \
  -e "KONG_PLUGINSERVER_NAMES=go-hello" \
  -e "KONG_PLUGINSERVER_GO_HELLO_QUERY_CMD=go-hello -dump" \
  -e "KONG_LOG_LEVEL=info" \
  kong-custom-go
```

### 🔍 Notes
* Kong is running in DB-less mode (KONG_DATABASE=off), so the config endpoint is used for declarative config.
* Environment variables configure Kong to recognize and use the custom Go plugin.

### 🔄 Check Container Status

```bash
docker ps
```

Expected output:

```
CONTAINER ID   IMAGE         ...   PORTS
999930ecfee7   kong-custom-go     ...   8000-8002->8000-8002/tcp
```

---

## 🔍 Validate Plugin Registration

```bash
curl http://localhost:8001 -s | jq .plugins | grep go-hello
```

Expected output:

```
"go-hello": {
```

---

## ⚙️ Configuration: test.yml

```yaml
_format_version: "2.1"
_transform: true

services:
- name: first-demo
  url: https://httpbin.org/anything
  routes:
  - name: first-demo-route
    paths:
    - /demo

plugins:
- name: go-hello
  enabled: true
  config:
    message: hello from go plugin
```

### 🧪 Apply Configuration

```bash
curl -X POST http://localhost:8001/config -F config=@test.yml
```

Expected response: JSON indicating successful configuration.

---

## ✅ Test the Custom Go Plugin

```bash
curl http://localhost:8000/demo -i
```

Expected response headers:

```
x-hello-from-go: Go says hello from go plugin to localhost:8000
```

And a body like:

```json
{
  "args": {},
  "data": "",
  ...
  "headers": {
    "X-Kong-Request-Id": "...",
    "X-Forwarded-Path": "/demo"
  },
  ...
}
```

---

## 📚 Reference

* [How to Install Kong Custom Go Plugin Example](https://tech.aufomm.com/how-to-install-kong-custom-go-plugin/)
* [Kong Go PDK](https://github.com/Kong/go-pdk)
* [Writing plugins in Go](https://developer.konghq.com/custom-plugins/go/)
---

## 🧼 Clean Up

To stop and remove the container:

```bash
docker stop kong-custom-go
```

---

