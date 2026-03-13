This is a `README.md` document for to add custom plugin to Konnect 


---

# 🛠️ Konnect Custom Plugin: `service-route-info`

A custom Kong Gateway plugin that logs and returns the **Service** and **Route** names involved in each request. This plugin is designed to work in **Konnect Hybrid Mode** using a custom-built Docker image of Kong Gateway.

---

## 📂 Directory Structure

```bash
kong-plugins/
└── service-route-info/
    ├── handler.lua
    └── schema.lua
```

---

## 📦 Plugin Behavior

* Logs service and route names on every request.
* Adds two custom response headers:

  * `X-Service-Name`
  * `X-Route-Name`

---

## 🧱 Plugin Code

### `handler.lua`

```lua
local ServiceRouteInfo = {
  PRIORITY = 10,
  VERSION = "1.0.0",
}

function ServiceRouteInfo:access(conf)
  local service = kong.router.get_service()
  local route = kong.router.get_route()
  kong.log.info("Service Name: ", service.name or "unknown")
  kong.log.info("Route Name: ", route.name or "unknown")
  kong.response.set_header("X-Service-Name", service.name or "N/A")
  kong.response.set_header("X-Route-Name", route.name or "N/A")
end

return ServiceRouteInfo
```

### `schema.lua`

```lua
return {
  name = "service-route-info",
  fields = {
    { config = {
        type = "record",
        fields = {}, -- No configuration options yet
      },
    },
  },
}
```

---

## 🐳 Building the Custom Docker Image

### `Dockerfile`

```Dockerfile
FROM kong/kong-gateway:3.10.0.2

# Switch to root to copy custom plugin
USER root

# Add custom plugin
COPY kong-plugins/service-route-info /usr/local/share/lua/5.1/kong/plugins/service-route-info

# Enable plugin via environment
ENV KONG_PLUGINS=bundled,service-route-info

# Revert back to kong user
USER kong

ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD kong health
CMD ["kong", "docker-start"]
```

### Build the Image

```bash
docker build -t kong-gateway-custom:3.10.0.2 .
```

---

## 🧪 Run & Register the Custom Image with Konnect

### 1. Stop Any Running Kong Gateway

```bash
docker ps
docker stop <container_id>
```

### 2. Start Konnect Data Plane

Save the following as `konnect_docker.yml` and run it to register with Konnect Control Plane:

```bash
docker run -d \
-e "KONG_ROLE=data_plane" \
-e "KONG_DATABASE=off" \
-e "KONG_VITALS=off" \
-e "KONG_LOG_LEVEL=info" \
-e "KONG_CLUSTER_MTLS=pki" \
-e "KONG_CLUSTER_CONTROL_PLANE=<CONTROL_PLANE_HOST>:443" \
-e "KONG_CLUSTER_SERVER_NAME=<CONTROL_PLANE_HOST>" \
-e "KONG_CLUSTER_TELEMETRY_ENDPOINT=<TELEMETRY_HOST>:443" \
-e "KONG_CLUSTER_TELEMETRY_SERVER_NAME=<TELEMETRY_HOST>" \
-e "KONG_CLUSTER_CERT=-----BEGIN CERTIFICATE-----
<REDACTED>
-----END CERTIFICATE-----" \
-e "KONG_CLUSTER_CERT_KEY=-----BEGIN PRIVATE KEY-----
<REDACTED>
-----END PRIVATE KEY-----" \
-e "KONG_LUA_SSL_TRUSTED_CERTIFICATE=system" \
-e "KONG_KONNECT_MODE=on" \
-e "KONG_CLUSTER_DP_LABELS=type:docker-macOsIntelOS" \
-e "KONG_ROUTER_FLAVOR=expressions" \
-p 8000:8000 \
-p 8443:8443 \
kong-gateway-custom:3.10.0.2
```

```bash
chmod +x konnect_docker.yml
./konnect_docker.yml
```

### 3. Confirm It’s Running

```bash
docker ps
```

---

## 📲 Test the Plugin

Ensure a route/service is configured and the plugin is enabled for it in Konnect. Then test:

```bash
curl -ik https://localhost:8443/test
```

You should see headers in the response like:

```http
X-Service-Name: test_svc
X-Route-Name: test_rt
```

---

## 📜 Logs Output

Logs confirming the plugin is working:

```log
[kong] handler.lua:10 [service-route-info] Service Name: test_svc
[kong] handler.lua:11 [service-route-info] Route Name: test_rt
```

---

## 🔗 Reference Documentation

* 📘 [Kong Plugin Development (Konnect)](https://developer.konghq.com/custom-plugins/konnect-hybrid-mode/)
* 🧠 [Build a Custom Lua Plugin](https://konghq.com/blog/engineering/custom-lua-plugin-kong-gateway)
* 📦 [Custom Plugin Installation & Distribution](https://developer.konghq.com/custom-plugins/installation-and-distribution/)
* 📄 [List Plugin Schemas (Konnect API)](https://developer.konghq.com/api/konnect/control-planes-config/v2/#/operations/list-plugin-schemas)

---

## ✅ Summary

| Component      | Description                      |
| -------------- | -------------------------------- |
| Plugin Name    | `service-route-info`             |
| Logs Info      | `Service Name`, `Route Name`     |
| Custom Headers | `X-Service-Name`, `X-Route-Name` |
| Kong Gateway   | `3.10.0.2` (custom image)        |
| Mode           | Hybrid with Konnect (data plane) |

---


