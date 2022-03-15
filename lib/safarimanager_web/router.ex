defmodule SMWeb.Router do
  use SMWeb, :router

  import SMWeb.UserAuth

  import Surface.Catalogue.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SMWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :jury_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SMWeb.LayoutView, :jury}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  # scope "/api", SMWeb do
  #   pipe_through :api
  # end

  scope "/", SMWeb do
    pipe_through :browser

    get "/", HomeController, :new
    live "/organize/new", NewCompetition
    live "/organize/:competition_id/participants", Participants
    live "/organize/:competition_id/jurors", Jurors
    live "/organize/:competition_id/slides", Slides
    live "/organize/:competition_id/csv_import", CSVImport
    live "/organize/:competition_id/jury_launcher", JuryLauncher

    # live "/", Main
    live "/gallery", Gallery
    live "/jury_viewer", JuryViewer
  end

  scope "/", SMWeb do
    pipe_through :jury_browser

    live "/organize/:competition_id/jury", Jury
  end

  scope "/admin", SMWeb do
    pipe_through :browser

    live "/organizations", Organizations
    live "/subjects", Subjects
    live "/competitions", Competitions
    live "/evaluations", Evaluations
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  # credo:disable-for-next-line Credo.Check.Warning.MixEnv
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # credo:disable-for-next-line Credo.Check.Warning.MixEnv
  if Mix.env() == :dev do
    scope "/" do
      pipe_through :browser
      surface_catalogue("/catalogue")
    end
  end

  ## Authentication routes

  scope "/", SMWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", SMWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", SMWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
