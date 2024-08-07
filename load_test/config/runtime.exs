import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: String.to_atom(System.get_env("LOG_LEVEL") || "info")

config :load_test, port: String.to_integer(System.get_env("PORT") || "2999")
config :load_test, nb_user: String.to_integer(System.get_env("NB_USER") || "1")
config :load_test, sse_timeout: String.to_integer(System.get_env("SSE_TIMEOUT") || "15000")
config :load_test, sse_base_url: System.get_env("SSE_BASE_URL") || "http://localhost:4000/sse"

config :load_test,
  rest_base_url: System.get_env("REST_BASE_URL") || "http://localhost:3000/publish"

config :load_test, rest_timeout: String.to_integer(System.get_env("REST_TIMEOUT") || "5000")

config :load_test,
  delay_between_messages_min:
    String.to_integer(System.get_env("DELAY_BETWEEN_MESSAGES_MIN") || "500")

config :load_test,
  delay_between_messages_max:
    String.to_integer(System.get_env("DELAY_BETWEEN_MESSAGES_MAX") || "5000")

config :load_test,
  number_of_messages_min: String.to_integer(System.get_env("NUMBER_OF_MESSAGES_MIN") || "10")

config :load_test,
  number_of_messages_max: String.to_integer(System.get_env("NUMBER_OF_MESSAGES_MAX") || "50")

config :load_test,
  initial_delay_max: String.to_integer(System.get_env("INITIAL_DELAY_MAX") || "5000")

config :load_test,
  http_pool_size: String.to_integer(System.get_env("HTTP_POOL_SIZE") || "2000")
