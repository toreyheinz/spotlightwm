import Config

# Configure your database
config :spotlight, Spotlight.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "spotlight_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :spotlight, SpotlightWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "1NN1Qp+Ed67vrvSbhNLm3yj1m4P7YbK+vCGuhgDhIeT4hnKhnS65QgMnfHvlmXtQ",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:spotlight, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:spotlight, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :spotlight, SpotlightWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/spotlight_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :spotlight, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
