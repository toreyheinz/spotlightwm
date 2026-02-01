defmodule Mix.Tasks.CreateUser do
  @moduledoc """
  Creates an admin user.

  ## Usage

      mix create_user "Name" "email@example.com"

  This will create the user and send them a magic link to log in.
  """
  use Mix.Task

  @shortdoc "Creates an admin user"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [name, email] ->
        create_user(name, email)

      _ ->
        Mix.shell().error("Usage: mix create_user \"Name\" \"email@example.com\"")
        exit({:shutdown, 1})
    end
  end

  defp create_user(name, email) do
    alias Spotlight.Accounts

    attrs = %{name: name, email: email}

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        Mix.shell().info("✅ User created: #{user.name} <#{user.email}>")

        # Generate and display a login link
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            fn token -> "#{SpotlightWeb.Endpoint.url()}/users/log-in/#{token}" end
          )

        Mix.shell().info("📧 Login instructions sent to #{user.email}")
        Mix.shell().info("   Check /dev/mailbox in development")

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        Mix.shell().error("❌ Failed to create user:")

        for {field, messages} <- errors do
          for message <- messages do
            Mix.shell().error("   #{field}: #{message}")
          end
        end

        exit({:shutdown, 1})
    end
  end
end
