defmodule ChesstrainerWeb.Router do
  use ChesstrainerWeb, :router

  import ChesstrainerWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChesstrainerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ChesstrainerWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/chess-test", ChessTestLive

    live "/endgames", EndgameLive.PlayerIndex, :index
  end

  scope "/admin", ChesstrainerWeb do
    pipe_through [:browser, :require_admin_user]

    live_session :endgames,
      on_mount: [{ChesstrainerWeb.UserAuth, :require_admin}] do
      live "/endgames", EndgameLive.Index, :index
      live "/endgames/new", EndgameLive.Form, :new
      live "/endgames/:id", EndgameLive.Show, :show
      live "/endgames/:id/edit", EndgameLive.Form, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChesstrainerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:chesstrainer, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChesstrainerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ChesstrainerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ChesstrainerWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", ChesstrainerWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ChesstrainerWeb.UserAuth, :mount_current_scope}] do
      live "/endgames/:public_code/play", EndgameLive.Play, :play
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/reset-password", UserLive.ResetPassword, :new
      live "/users/reset-password/:token", UserLive.ResetPassword, :edit
    end

    get "/users/confirm/:token", UserConfirmationController, :edit

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
