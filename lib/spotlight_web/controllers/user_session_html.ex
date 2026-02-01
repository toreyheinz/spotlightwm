defmodule SpotlightWeb.UserSessionHTML do
  use SpotlightWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:spotlight, Spotlight.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
