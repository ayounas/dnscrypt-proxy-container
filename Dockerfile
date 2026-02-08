# Build stage
FROM golang:alpine AS builder

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
        (git checkout "$DNSCRYPT_VERSION" || \
         git checkout "v$DNSCRYPT_VERSION" || \
         echo "Could not checkout specific tag, using master"); \
    fi && \
    cp /tmp/dnscrypt-repo/dnscrypt-proxy/example-dnscrypt-proxy.toml /build/dnscrypt-proxy.toml

# Configure dnscrypt-proxy.toml
# 1. Listen on 0.0.0.0:5353 (Non-root port)
# 2. Use 'cloudflare' server
# 3. Disable IPv6 output if needed (optional, but safer to keep unless requested) - keep default
# 4. Ensure require_dnssec is true? user didn't ask, but good practice.
RUN sed -i "s/^listen_addresses = .*/listen_addresses = ['0.0.0.0:5353']/" /build/dnscrypt-proxy.toml && \
    sed -i "s/^# server_names = .*/server_names = ['cloudflare']/" /build/dnscrypt-proxy.toml

# checkov:skip=CKV_DOCKER_7:Usage of latest tag is intended to fetch security updates for the base image automatically
# Runtime stage - Using Debian 13 "Trixie" based distroless
FROM gcr.io/distroless/static-debian13:nonroot

WORKDIR /app

# Copy files with ownership for user 65532 (nonroot)
COPY --from=builder --chown=65532:65532 /go/bin/dnscrypt-proxy /app/dnscrypt-proxy
COPY --from=builder --chown=65532:65532 /build/healthcheck /app/healthcheck
COPY --from=builder --chown=65532:65532 /build/dnscrypt-proxy.toml /app/dnscrypt-proxy.toml

USER nonroot

EXPOSE 5353/tcp 5353/udp

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD ["/app/healthcheck"]

ENTRYPOINT ["/app/dnscrypt-proxy"]
CMD ["-config", "/app/dnscrypt-proxy.toml"]
