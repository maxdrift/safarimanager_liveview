defmodule SMWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use SMWeb, :controller
      use SMWeb, :html

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def controller do
    quote do
      use Phoenix.Controller,
        namespace: SMWeb

      import Plug.Conn
      import SMWeb.Gettext

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [view_module: 1, view_template: 1]

      import Phoenix.Flash, only: [get: 2]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {SMWeb.LayoutHTML, :live}

      unquote(view_helpers())
    end
  end

  def surface_view do
    quote do
      use Surface.LiveView,
        layout: {SMWeb.LayoutHTML, :live}

      unquote(view_helpers())
    end
  end

  def surface_component do
    quote do
      use Surface.Component

      import SMWeb.ErrorHelpers
    end
  end

  def surface_live_component do
    quote do
      use Surface.LiveComponent

      import SMWeb.ErrorHelpers
    end
  end

  def surface_jury_view do
    quote do
      use Surface.LiveView,
        layout: {SMWeb.LayoutHTML, :live_jury}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import SMWeb.Gettext
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: SMWeb.Endpoint,
        router: SMWeb.Router,
        statics: SMWeb.static_paths()
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import Phoenix.Component

      import SMWeb.ErrorHelpers
      import SMWeb.Gettext

      unquote(verified_routes())
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
