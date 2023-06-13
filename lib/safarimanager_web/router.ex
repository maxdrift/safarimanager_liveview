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
    pipe_through [:browser]

    get "/", HomeController, :new
    # TODO: Move under authenticated routes
    post "/export", CSVExportController, :create
    get "/:competition_id/print_results", PrintResultsController, :show
  end

  scope "/", SMWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SMWeb.UserAuth, :ensure_authenticated}, SMWeb.Confirm] do
      scope "/organize" do
        live "/new", NewCompetition
        live "/:competition_id/participants", Participants
        live "/:competition_id/jurors", Jurors
        live "/:competition_id/slides", Slides
        live "/:competition_id/slide_selection", SlideSelection
        live "/:competition_id/validation_launcher", ValidationLauncher
        live "/:competition_id/validation", Validation
        live "/:competition_id/jury_launcher", JuryLauncher
        live "/:competition_id/jury", Jury
        live "/:competition_id/results", Results
      end

      scope "/admin", Components.Admin do
        live "/organizations", Organizations
        live "/subjects", SubjectsLive.Index, :index
        live "/subjects/new", SubjectsLive.Index, :new
        live "/subjects/:id", SubjectsLive.Index, :show
        live "/subjects/:id/edit", SubjectsLive.Index, :edit
        live "/competitions", Competitions
        live "/evaluations", Evaluations
        live "/users", Users
        live "/categories", Categories
        live "/participants", Participants
        live "/import", Import
      end

      live "/gallery", Gallery
      live "/jury_viewer", JuryViewer

      scope "/users" do
        live "/settings", UserSettingsLive, :edit
        live "/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      end
    end
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
      on_mount: [{SMWeb.UserAuth, :redirect_if_user_is_authenticated}, SMWeb.Confirm] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", SMWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{SMWeb.UserAuth, :mount_current_user}, SMWeb.Confirm] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
