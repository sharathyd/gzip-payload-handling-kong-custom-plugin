````markdown
# 🧩 Kong Gateway 3.8.0+ – Custom Plugin Redis Migration Guide

This guide explains the **breaking changes in Kong Gateway 3.8.0** that affect custom plugins using shared Redis config. It also provides sample Redis-based plugin code, schema examples, and references for **AWS ElastiCache Redis** and **Redis Sentinel** setups.

---

## ⚠️ Breaking Changes in Kong 3.8.0

In Kong Gateway **3.8.0**, custom plugins that used **shared Redis configuration** are impacted.  
You need to migrate to the **new Redis v2 API**.

📖 More details:  
- [Breaking Changes – Custom Plugins with Shared Redis Config](https://developer.konghq.com/gateway/breaking-changes/#custom-plugins-that-used-shared-redis-config)  
- [Upgrade Guide (3.4 → 3.10 LTS)](https://developer.konghq.com/gateway/upgrade/lts-upgrade-34-310/#removed-or-deprecated)  

---

## ☁️ AWS ElastiCache Redis Use Case

AWS ElastiCache Redis is often used for:
- **Caching** frequently accessed data  
- **Session storage** across distributed services  
- **Rate limiting** and **quota enforcement** in API gateways  
- **Pub/Sub messaging**  

📖 Reference: [AWS ElastiCache Redis Use Cases](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/elasticache-use-cases.html)

---

## 🔄 Redis Sentinel

Redis Sentinel provides:
- **High availability** for Redis  
- **Automatic failover** if the master node fails  
- **Monitoring** and **notification system**  

📖 Reference: [Redis Sentinel Documentation](https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/)

---

## 🛠️ Custom Plugin Development

If you are building a **custom Redis-based plugin** in Kong 3.8.0+, you should use the **Redis v2 library**.

📖 Reference: [Custom Plugin Guidelines](https://docs.google.com/document/d/1R7LpNyB7_3KXJdhfpAzlz12pxVgjg-Mzk6Ayn4bP9zc/edit?tab=t.0)

---

## 📜 Sample Plugin Code (Redis v2)

> ⚠️ This code is for **illustration only** and is **not production-tested**.

```lua
local kong   = kong
local redis  = require "kong.enterprise_edition.tools.redis.v2"
local ngx_null = ngx.null

local Plugin = {
  PRIORITY = 0,
  VERSION  = "1.0",
}

local function maybe_keepalive(red, conf)
  if not redis.is_redis_cluster(conf.redis) then
    red:set_keepalive(55 * 1000, 1000)
  end
end

function Plugin:access(conf)
  local key = kong.request.get_header("x-key")
  if not key or key == "" then
    return kong.response.exit(400, { message = "Missing x-key header" })
  end

  local red, err = redis.connection(conf.redis)
  if not red then
    return kong.response.exit(500, { message = "Redis connect failed: " .. tostring(err) })
  end

  local val, gerr = red:get(key)
  if gerr then
    maybe_keepalive(red, conf)
    return kong.response.exit(500, { message = "Redis get failed: " .. tostring(gerr) })
  end

  if val and val ~= ngx_null then
    maybe_keepalive(red, conf)
    return kong.response.exit(200, { key = key, value = val })
  end

  local new_val = ngx.md5(ngx.now() .. ":" .. key)
  local ok, serr = red:set(key, new_val)
  if not ok then
    maybe_keepalive(red, conf)
    return kong.response.exit(500, { message = "Redis set failed: " .. tostring(serr) })
  end

  maybe_keepalive(red, conf)
  return kong.response.exit(200, { key = key, value = new_val })
end

return Plugin
````

---

## 🗂️ Schema Example

```lua
local redis    = require "kong.enterprise_edition.tools.redis.v2"
local typedefs = require "kong.db.schema.typedefs"

return {
  name = "my-redis-plugin",
  supported_partials = {
    ["redis-ee"] = { "config.redis" },
  },
  fields = {
    { consumer  = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          -- Plugin-specific fields can be added here
          -- { example = { type = "string", required = false } },

          -- Full Redis v2 schema (standalone, sentinel, cluster, TLS, proxied)
          { redis = redis.config_schema },
        },
      },
    },
  },
}
```

---

## 📚 References

* [Breaking Changes in Kong 3.8.0](https://developer.konghq.com/gateway/breaking-changes/#custom-plugins-that-used-shared-redis-config)
* [Upgrade Guide (3.4 → 3.10 LTS)](https://developer.konghq.com/gateway/upgrade/lts-upgrade-34-310/#removed-or-deprecated)
* [AWS ElastiCache Redis Use Cases](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/elasticache-use-cases.html)
* [Redis Sentinel Documentation](https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/)
* [Custom Plugin Guidelines (Google Doc)](https://docs.google.com/document/d/1R7LpNyB7_3KXJdhfpAzlz12pxVgjg-Mzk6Ayn4bP9zc/edit?tab=t.0)

---

