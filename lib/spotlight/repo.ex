defmodule Spotlight.Repo do
  use Ecto.Repo,
    otp_app: :spotlight,
    adapter: Ecto.Adapters.Postgres
end
