defmodule SMWeb.SidebarHook do
  @moduledoc false
  use Gettext, backend: SMWeb.Gettext

  import Phoenix.LiveView
  import SMWeb.Components.Confirm

  require Logger

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SM.PubSub, "sidebar")
    end

    socket =
      socket
      |> attach_hook(:shutdown, :handle_info, &handle_info/2)
      |> attach_hook(:shutdown, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  defp handle_info(:shutdown, socket) do
    {:halt,
     put_flash(
       socket,
       :info,
       gettext("Safari Manager is shutting down. You can close this page.")
     )}
  end

  defp handle_info(_event, socket), do: {:cont, socket}

  defp handle_event("shutdown", _params, socket) do
    on_confirm = fn socket ->
      SM.Config.shutdown()
      socket
    end

    {:halt,
     confirm(socket, on_confirm,
       title: gettext("Shut Down"),
       description: gettext("Are you sure you want to shut down Safari Manager now?"),
       confirm_text: gettext("Shut Down"),
       confirm_icon: "power"
     )}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}
end
