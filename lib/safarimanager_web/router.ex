defmodule SMWeb.Router do
  use SMWeb, :router

  import SMWeb.UserAuth

  import Surface.Catalogue.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SMWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :jury_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SMWeb.Layouts, :jury}
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
    live "/organize/:competition_id/validation_launcher", ValidationLauncher
    live "/organize/:competition_id/jury_launcher", JuryLauncher
    live "/organize/:competition_id/results", Results

    # live "/", Main
    live "/gallery", Gallery
    live "/jury_viewer", JuryViewer
  end

  scope "/", SMWeb do
    pipe_through :jury_browser

    live "/organize/:competition_id/jury", Jury
    live "/organize/:competition_id/validation", Validation
  end

  scope "/admin", SMWeb.Components.Admin do
    pipe_through :browser

    live "/organizations", Organizations
    live "/subjects", Subjects
    live "/competitions", Competitions
    live "/evaluations", Evaluations
    live "/users", Users
    live "/categories", Categories
    live "/participants", Participants
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

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{SMWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", SMWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SMWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", SMWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{SMWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
