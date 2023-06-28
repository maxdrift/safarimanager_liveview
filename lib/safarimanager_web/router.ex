defmodule SMWeb.Router do
  use SMWeb, :router

  import SMWeb.UserAuth

  import Surface.Catalogue.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SMWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :jury_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SMWeb.Layouts, :jury}
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
    get "/:competition_id/results_printout", ResultsPrintoutController, :show
    get "/:competition_id/slides_printout", SlidesPrintoutController, :show
    get "/:competition_id/participants_printout", ParticipantsPrintoutController, :show
    get "/:competition_id/selection_printout", SelectionPrintoutController, :show
    get "/:competition_id/:user_id/selection_printout", SelectionPrintoutController, :show
  end

  scope "/", SMWeb.Live do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SMWeb.UserAuth, :ensure_authenticated}, SMWeb.Components.Confirm] do
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

      scope "/admin", Admin do
        live "/organizations", Organizations.Index, :index
        live "/organizations/new", Organizations.Index, :new
        live "/organizations/:id", Organizations.Index, :show
        live "/organizations/:id/edit", Organizations.Index, :edit
        live "/subjects", Subjects.Index, :index
        live "/subjects/new", Subjects.Index, :new
        live "/subjects/:id", Subjects.Index, :show
        live "/subjects/:id/edit", Subjects.Index, :edit
        live "/competitions", Competitions.Index, :index
        live "/competitions/new", Competitions.Index, :new
        live "/competitions/:id", Competitions.Index, :show
        live "/competitions/:id/edit", Competitions.Index, :edit
        live "/evaluations", Evaluations.Index, :index
        live "/evaluations/new", Evaluations.Index, :new
        live "/evaluations/:id", Evaluations.Index, :show
        live "/evaluations/:id/edit", Evaluations.Index, :edit
        live "/users", Users.Index, :index
        live "/users/new", Users.Index, :new
        live "/users/:id", Users.Index, :show
        live "/users/:id/edit", Users.Index, :edit
        live "/categories", Categories.Index, :index
        live "/categories/new", Categories.Index, :new
        live "/categories/:id", Categories.Index, :show
        live "/categories/:id/edit", Categories.Index, :edit
        live "/participants", Participants.Index, :index
        live "/participants/new", Participants.Index, :new
        live "/participants/:user_id/:competition_id", Participants.Index, :show
        live "/participants/:user_id/:competition_id/edit", Participants.Index, :edit
        live "/import", Import
      end

      live "/gallery", Gallery

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
      on_mount: [{SMWeb.UserAuth, :redirect_if_user_is_authenticated}, SMWeb.Components.Confirm] do
      live "/users/register", Live.UserRegistrationLive, :new
      live "/users/log_in", Live.UserLoginLive, :new
      live "/users/reset_password", Live.UserForgotPasswordLive, :new
      live "/users/reset_password/:token", Live.UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", SMWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{SMWeb.UserAuth, :mount_current_user}, SMWeb.Components.Confirm] do
      live "/users/confirm/:token", Live.UserConfirmationLive, :edit
      live "/users/confirm", Live.UserConfirmationInstructionsLive, :new
    end
  end
end
