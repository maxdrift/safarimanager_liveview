defmodule SMWeb.Router do
  use SMWeb, :router

  import Surface.Catalogue.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SMWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  # scope "/api", SMWeb do
  #   pipe_through :api
  # end

  scope "/", SMWeb do
    pipe_through :browser

    live "/organizations", Organizations
    live "/subjects", Subjects

    # live "/", Main
    live "/gallery", Gallery
    live "/jury_viewer", JuryViewer
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
end
