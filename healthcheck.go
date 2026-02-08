package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"time"
)

func main() {
	// Configure the resolver to talk to localhost:53
	resolver := &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
			d := net.Dialer{
				Timeout: time.Millisecond * 500,
			}
			return d.DialContext(ctx, "udp", "127.0.0.1:5353")
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Perform a DNS lookup. resolving cloudflare.com is a good test.
	_, err := resolver.LookupHost(ctx, "cloudflare.com")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Healthcheck failed: %v\n", err)
		os.Exit(1)
	}

	os.Exit(0)
}
