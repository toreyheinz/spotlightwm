import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/spotlight start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
# Load .env.dev in dev/test (so you don't need to manually source it)
if config_env() in [:dev, :test] do
  env_file = Path.expand("../.env.dev", __DIR__)

  if File.exists?(env_file) do
    for line <- File.read!(env_file) |> String.split("\n"),
        line = String.trim(line),
        line != "" and not String.starts_with?(line, "#"),
        [key | rest] = String.split(line, "=", parts: 2),
        rest != [] do
      System.put_env(key, hd(rest))
    end
  end
end

# R2 storage credentials (required in prod, optional in dev/test)
if r2_access_key = System.get_env("R2_ACCESS_KEY_ID") do
  config :ex_aws,
    access_key_id: r2_access_key,
    secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY") || raise("missing R2_SECRET_ACCESS_KEY")
end

if System.get_env("PHX_SERVER") do
  config :spotlight, SpotlightWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :spotlight, Spotlight.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "spotlightwm.org"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :spotlight, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :spotlight, SpotlightWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  config :spotlight, :uploads_prefix, "prod"

  config :spotlight, Spotlight.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key: System.get_env("POSTMARK_API_KEY") || raise("missing POSTMARK_API_KEY")
end
