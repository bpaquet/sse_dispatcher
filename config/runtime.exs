import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: String.to_atom(System.get_env("LOG_LEVEL") || "info")

config :sse_dispatcher, sse_port: String.to_integer(System.get_env("SSE_PORT") || "4000")
config :sse_dispatcher, rest_port: String.to_integer(System.get_env("REST_PORT") || "3000")
config :sse_dispatcher, sse_timeout: String.to_integer(System.get_env("SSE_TIMEOUT") || "900000")

config :sse_dispatcher,
  max_connections: String.to_integer(System.get_env("MAX_CONNECTIONS") || "100000")
