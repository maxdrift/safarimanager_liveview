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

  def static_paths, do: ~w(assets fonts images robots.txt)

  def controller do
    quote do
      use Phoenix.Controller,
        namespace: SMWeb,
        formats: [:html, :json],
        layouts: [html: SMWeb.Layouts]

      import Plug.Conn
      import SMWeb.Gettext

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {SMWeb.Layouts, :live}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def surface_view do
    quote do
      use Surface.LiveView,
        layout: {SMWeb.Layouts, :live}

      unquote(html_helpers())
    end
  end

  def surface_component do
    quote do
      use Surface.Component

      import SMWeb.ErrorHelpers
      import SMWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def surface_live_component do
    quote do
      use Surface.LiveComponent

      import SMWeb.ErrorHelpers

      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Phoenix.Controller
      import Phoenix.LiveView.Router
      import Plug.Conn
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
        # credo:disable-for-next-line
        statics: SMWeb.static_paths() ++ ["uploads"]

      import SMWeb.Gettext
    end
  end

  def live_action_to_changeset_action(live_action) do
    case live_action do
      :new -> :create
      :edit -> :edit
      _index -> nil
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      import SMWeb.Components.Confirm
      # Core UI components and translation
      import SMWeb.Components.CoreComponents
      import SMWeb.ErrorHelpers

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
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
