FROM debian:bookworm-slim AS download
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip
RUN curl --fail --show-error --location --retry 3 \
    https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip \
    --output /tmp/godot.zip && unzip -q /tmp/godot.zip -d /tmp && \
    mv /tmp/Godot_v4.7.2-stable_linux.x86_64 /godot

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libfontconfig1 && rm -rf /var/lib/apt/lists/*
COPY --from=download /godot /usr/local/bin/godot
WORKDIR /app
COPY project.godot relay.gd ./
ENV PORT=10000
EXPOSE 10000
USER 65534:65534
CMD ["godot", "--headless", "--path", "/app", "--script", "relay.gd", "--max-fps", "60"]
