defmodule SpotlightWeb.Router do
  use SpotlightWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SpotlightWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SpotlightWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/about", PageController, :about
    get "/productions", PageController, :productions
    get "/golden-quill", PageController, :golden_quill
    get "/contact", PageController, :contact
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:spotlight, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SpotlightWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
