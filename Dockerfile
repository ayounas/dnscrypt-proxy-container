# Build stage
FROM golang:1.23-alpine AS builder

ARG DNSCRYPT_VERSION=latest

WORKDIR /build

# Install git for fetching source/config
RUN apk add --no-cache git

# Install dnscrypt-proxy
# If DNSCRYPT_VERSION is provided (e.g. v2.1.15), usage with @version, else @latest
RUN if [ "$DNSCRYPT_VERSION" = "latest" ] || [ -z "$DNSCRYPT_VERSION" ]; then \
        target="latest"; \
    else \
        target="$DNSCRYPT_VERSION"; \
    fi && \
    echo "Building version: $target" && \
    go install -v -trimpath -ldflags="-s -w" github.com/DNSCrypt/dnscrypt-proxy/dnscrypt-proxy@$target

# Build static healthcheck binary
COPY healthcheck.go .
# CGO_ENABLED=0 is default for alpine go usually, but let's be explicit for static binary
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o healthcheck healthcheck.go

# Fetch default config
# We clone the repo to get the example config file corresponding to the version
RUN git clone https://github.com/DNSCrypt/dnscrypt-proxy.git /tmp/dnscrypt-repo && \
    if [ "$DNSCRYPT_VERSION" != "latest" ] && [ -n "$DNSCRYPT_VERSION" ]; then \
        cd /tmp/dnscrypt-repo && \
        # Try to checkout the tag, if it fails (maybe v prefix issue), try with v
        (git checkout "$DNSCRYPT_VERSION" || git checkout "v$DNSCRYPT_VERSION" || echo "Could not checkout specific tag, using master"); \
    fi && \
    cp /tmp/dnscrypt-repo/dnscrypt-proxy/example-dnscrypt-proxy.toml /build/dnscrypt-proxy.toml

# Configure dnscrypt-proxy.toml
# 1. Listen on 0.0.0.0:53
# 2. Use 'cloudflare' server
# 3. Disable IPv6 output if needed (optional, but safer to keep unless requested) - keep default
# 4. Ensure require_dnssec is true? user didn't ask, but good practice.
RUN sed -i "s/^listen_addresses = .*/listen_addresses = ['0.0.0.0:53']/" /build/dnscrypt-proxy.toml && \
    sed -i "s/^# server_names = .*/server_names = ['cloudflare']/" /build/dnscrypt-proxy.toml

# Runtime stage
FROM gcr.io/distroless/static-debian12

WORKDIR /app

COPY --from=builder /go/bin/dnscrypt-proxy /app/dnscrypt-proxy
COPY --from=builder /build/healthcheck /app/healthcheck
COPY --from=builder /build/dnscrypt-proxy.toml /app/dnscrypt-proxy.toml

EXPOSE 53/tcp 53/udp

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD ["/app/healthcheck"]

ENTRYPOINT ["/app/dnscrypt-proxy"]
CMD ["-config", "/app/dnscrypt-proxy.toml"]
