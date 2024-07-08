import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: String.to_atom(System.get_env("LOG_LEVEL") || "info")

config :sse_dispatcher, sse_port: String.to_integer(System.get_env("SSE_PORT") || "4000")
config :sse_dispatcher, rest_port: String.to_integer(System.get_env("REST_PORT") || "3000")

config :sse_dispatcher,
  prometheus_port: String.to_integer(System.get_env("PROMETHEUS_PORT") || "9000")

config :sse_dispatcher, sse_timeout: String.to_integer(System.get_env("SSE_TIMEOUT") || "900000")

config :sse_dispatcher, ssl_keyfile: System.get_env("SSL_KEYFILE")
config :sse_dispatcher, ssl_certfile: System.get_env("SSL_CERTFILE")
