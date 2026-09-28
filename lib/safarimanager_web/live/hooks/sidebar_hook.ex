defmodule SMWeb.SidebarHook do
  @moduledoc false
  use Gettext, backend: SMWeb.Gettext

  import Phoenix.Component, only: [assign: 2, assign_new: 3]
  import Phoenix.LiveView
  import SMWeb.Components.Confirm

  alias SM.CompetitionDirectories

  require Logger

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SM.PubSub, "sidebar")
      CompetitionDirectories.subscribe()
    end

    socket =
      socket
      |> assign_new(:originals_status, fn -> :unknown end)
      |> assign_new(:originals_competition_id, fn -> nil end)
      |> attach_hook(:sidebar, :handle_params, &handle_params/3)
      |> attach_hook(:sidebar, :handle_info, &handle_info/2)
      |> attach_hook(:sidebar, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  # The Monitor keeps the cache fresh; never touch the filesystem from the LiveView process here.
  defp handle_params(params, _uri, socket) do
    competition_id = params["competition_id"]

    status = if competition_id, do: CompetitionDirectories.get_reachability(competition_id), else: :unknown

    {:cont, assign(socket, originals_competition_id: competition_id, originals_status: status)}
  end

  defp handle_info({CompetitionDirectories, [:originals_reachability, competition_id], status}, socket) do
    if socket.assigns.originals_competition_id == competition_id do
      {:halt, assign(socket, originals_status: status)}
    else
      {:halt, socket}
    end
  end

  defp handle_info({CompetitionDirectories, _event, _payload}, socket), do: {:halt, socket}

  defp handle_info(:shutdown, socket) do
    {:halt,
     put_flash(
       socket,
       :info,
       gettext("Safari Manager is shutting down. You can close this page.")
     )}
  end

  defp handle_info(_event, socket), do: {:cont, socket}

  defp handle_event("originals-retry", _params, socket) do
    {:halt, retry_originals(socket, socket.assigns.originals_competition_id)}
  end

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

  defp retry_originals(socket, nil), do: socket

  defp retry_originals(socket, competition_id) do
    case CompetitionDirectories.check_reachability_with_timeout(competition_id) do
      :unreachable ->
        socket
        |> assign(originals_status: :unreachable)
        |> put_flash(:error, gettext("Original slide images are still unreachable."))

      status ->
        assign(socket, originals_status: status)
    end
  end
end
