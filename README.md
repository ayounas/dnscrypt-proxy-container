# DNSCrypt-Proxy Docker Container

A minimal, secure Docker container for [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy), built on `distroless` and automatically updated.

## Features

- **Base**: `gcr.io/distroless/static-debian12` (No shell, minimal attack surface).
- **Configuration**: Pre-configured to use **Cloudflare** as the upstream DoH provider.
- **Healthcheck**: Built-in Go-based healthcheck that verifies DNS resolution via the proxy.
- **Architecture**: Supports `linux/amd64` and `linux/arm64`.
- **Updates**: 
  - Checks for new upstream `dnscrypt-proxy` releases **daily**.
  - Checks for **distroless base image updates** daily and rebuilds immediately if a security update is found.

## Usage

### Run with Docker

```bash
docker run -d \
  --name dnscrypt-proxy \
  -p 53:53/udp \
  -p 53:53/tcp \
  ghcr.io/YOUR_USERNAME/dnscrypt-proxy-container:latest
```

*Note: Replace `YOUR_USERNAME` with your GitHub username.*

### Custom Configuration

To use your own `dnscrypt-proxy.toml`:

1.  Get the [default config](https://github.com/DNSCrypt/dnscrypt-proxy/blob/master/dnscrypt-proxy/example-dnscrypt-proxy.toml).
2.  Edit it.
3.  Mount it into the container:

```bash
docker run -d \
  --name dnscrypt-proxy \
  -p 53:53/udp \
  -p 53:53/tcp \
  -v $(pwd)/dnscrypt-proxy.toml:/app/dnscrypt-proxy.toml \
  ghcr.io/YOUR_USERNAME/dnscrypt-proxy-container:latest
```

## GitHub Actions

The repository includes a GitHub Actions workflow that:
- Runs automatically on schedule (Hourly check, Weekly rebuild).
- Publishes images to [GitHub Container Registry](https://ghcr.io).

**Important**: 
1.  Ensure your GitHub repository visibility allows for Public/Private packages as desired. For "no auth" usage, change the package visibility to **Public** in the Package Settings on GitHub after the first push.
2.  Enable `Read and Write permissions` for `GITHUB_TOKEN` in Repository Settings -> Actions -> General -> Workflow permissions (or the workflow file handles permissions, but package settings usually need initial setup).
