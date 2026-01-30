defmodule SpotlightWeb.PageController do
  use SpotlightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def productions(conn, _params) do
    render(conn, :productions)
  end

  def golden_quill(conn, _params) do
    render(conn, :golden_quill)
  end

  def contact(conn, _params) do
    render(conn, :contact)
  end
end
