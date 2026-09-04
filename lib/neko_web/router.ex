defmodule NekoWeb.Router do
  use NekoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NekoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug NekoWeb.Plugs.AdminBasicAuth
  end

  scope "/", NekoWeb do
    pipe_through :browser

    get "/", PageController, :home
    post "/rsvp", PageController, :rsvp
    post "/rsvp/check", PageController, :check_rsvp
    post "/rsvp/reset", PageController, :reset_rsvp
  end

  scope "/admin", NekoWeb.Admin do
    pipe_through [:browser, :admin]

    get "/", RsvpController, :index
    get "/guests", RsvpController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", NekoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:neko, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NekoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
