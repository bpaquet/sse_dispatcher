#!/bin/sh -e

echo "*** SSE Dispatcher ***"

if [ "$USE_HAPROXY" != "" ]; then
  echo "Starting Haproxy"
  cat "$SSL_CERTFILE" "$SSL_KEYFILE" > /tmp/combined.pem
  haproxy -c -f /haproxy.cfg
  haproxy -f /haproxy.cfg &

  export SSE_PORT=4001
  unset SSL_KEYFILE
  unset SSL_CERTFILE
fi

if [ "$POD_IP" != "" ]; then
  export RELEASE_DISTRIBUTION="name"
  export RELEASE_NODE="sse_dispatcher@${POD_IP}"
  echo "Starting Elixir daemon, node: $RELEASE_NODE"
else
  echo "Starting Elixir daemon"
fi

exec /app/bin/sse_dispatcher start
