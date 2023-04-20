defmodule SMWeb.SidebarHook do
  require Logger

  import Phoenix.LiveView

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
    {:halt, put_flash(socket, :info, "Safari Manager is shutting down. You can close this page.")}
  end

  defp handle_info(_event, socket), do: {:cont, socket}

  defp handle_event("shutdown", _params, socket) do
    SM.Config.shutdown()
    {:halt, socket}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}
end
