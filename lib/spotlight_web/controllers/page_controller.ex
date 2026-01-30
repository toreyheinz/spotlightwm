defmodule SpotlightWeb.PageController do
  use SpotlightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
