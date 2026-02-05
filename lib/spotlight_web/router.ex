defmodule SpotlightWeb.Router do
  use SpotlightWeb, :router

  import SpotlightWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SpotlightWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
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

  ## Authentication routes
  # Note: No public registration - users are added by admins

  scope "/", SpotlightWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", SpotlightWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## Admin routes

  scope "/admin", SpotlightWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user]

    live_session :admin,
      on_mount: [{SpotlightWeb.UserAuth, :ensure_authenticated}],
      layout: {SpotlightWeb.Layouts, :admin},
      root_layout: {SpotlightWeb.Layouts, :admin_root} do
      live "/", DashboardLive, :index
      live "/productions", ProductionLive.Index, :index
      live "/productions/new", ProductionLive.Index, :new
      live "/productions/:id", ProductionLive.Show, :show
      live "/productions/:id/edit", ProductionLive.Show, :edit
      live "/users", UserLive.Index, :index
      live "/users/new", UserLive.Index, :new
    end
  end
end
