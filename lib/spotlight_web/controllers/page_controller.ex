defmodule SpotlightWeb.PageController do
  use SpotlightWeb, :controller

  def home(conn, _params) do
    next_production =
      Spotlight.Productions.list_upcoming_productions()
      |> List.first()

    render(conn, :home, next_production: next_production)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def productions(conn, _params) do
    upcoming = Spotlight.Productions.list_upcoming_productions()
    past = Spotlight.Productions.list_past_productions()
    render(conn, :productions, upcoming: upcoming, past: past)
  end

  def production_show(conn, %{"slug" => slug}) do
    production = Spotlight.Productions.get_published_production_by_path!(slug)
    path = Spotlight.Productions.production_path(production)

    og = %{
      title: production.title,
      description: strip_html(production.description),
      url: unverified_url(conn, "/productions/" <> path),
      image: production.main_image_url && unverified_url(conn, "/images/w/1200" <> production.main_image_url)
    }

    conn
    |> assign(:page_title, production.title)
    |> render(:production_show, production: production, og: og)
  end

  defp strip_html(nil), do: nil

  defp strip_html(html) do
    html
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 200)
  end

  def golden_quill(conn, _params) do
    render(conn, :golden_quill)
  end

  def contact(conn, _params) do
    render(conn, :contact)
  end
end
