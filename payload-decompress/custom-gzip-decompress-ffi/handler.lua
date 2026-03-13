local ffi_zlib = require("ffi-zlib")
local kong = kong

local GzipDecompressHandler = {
  VERSION = "1.0.0",
  PRIORITY = 2000,
}

function GzipDecompressHandler:access(config)
  local encoding = kong.request.get_header("Content-Encoding")
  if encoding and encoding:lower():find("gzip") then

    local compressed_body = kong.request.get_raw_body()
    if not compressed_body or #compressed_body == 0 then
      return kong.response.exit(400, "Empty compressed body")
    end

    local input_data = compressed_body
    local pos = 1

    local function input(chunk_size)
      if pos > #input_data then return nil end
      local chunk = input_data:sub(pos, pos + chunk_size - 1)
      pos = pos + #chunk
      return chunk
    end

    local decompressed_chunks = {}

    local function output(data)
      table.insert(decompressed_chunks, data)
      return true
    end

    local ok, err = ffi_zlib.inflateGzip(input, output)
    if not ok then
      kong.log.err("gzip decompress error: ", err)
      return kong.response.exit(400, "Invalid gzip payload")
    end

    local decompressed_body = table.concat(decompressed_chunks)

    kong.service.request.set_raw_body(decompressed_body)
    kong.service.request.clear_header("Content-Encoding")
    kong.service.request.set_header("Content-Length", #decompressed_body)
  end
end

return GzipDecompressHandler

