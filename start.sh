#!/bin/sh -e

echo "*** SSE Dispatcher"

if [ -z "$USE_HAPROXY" ]; then
  echo "Starting Haproxy"
  cat "$SSL_CERTFILE" "$SSL_KEYFILE" > /tmp/combined.pem
  haproxy -c -f /haproxy.cfg
  haproxy -f /haproxy.cfg &

  export SSE_PORT=4001
  unset SSL_KEYFILE
  unset SSL_CERTFILE
fi

echo "Starting Elixir daemon"
exec /app/bin/sse_dispatcher start
