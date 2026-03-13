FROM kong/kong-gateway:3.10.0.2

USER root

COPY lua-ffi-zlib-0.6-0.rockspec /tmp/
RUN luarocks install /tmp/lua-ffi-zlib-0.6-0.rockspec


# Update and install dependencies
#RUN apt-get update && apt-get install -y unzip build-essential

# Install lua-ffi-zlib via luarocks inside container
#RUN luarocks install lua-ffi-zlib

# Copy your plugin into the Kong plugins directory
COPY custom-gzip-decompress-ffi /usr/local/share/lua/5.1/kong/plugins/custom-gzip-decompress-ffi

# Add your plugin to KONG_PLUGINS environment variable
ENV KONG_PLUGINS=bundled,custom-gzip-decompress-ffi

USER kong

ENTRYPOINT ["/entrypoint.sh"]
CMD ["kong", "docker-start"]

