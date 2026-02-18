defmodule SpotlightWeb.PageController do
  use SpotlightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def productions(conn, _params) do
    upcoming = Spotlight.Productions.list_upcoming_productions()
    past = Spotlight.Productions.list_past_productions()
    render(conn, :productions, upcoming: upcoming, past: past)
  end

  def golden_quill(conn, _params) do
    render(conn, :golden_quill)
  end

  def contact(conn, _params) do
    render(conn, :contact)
  end
end
