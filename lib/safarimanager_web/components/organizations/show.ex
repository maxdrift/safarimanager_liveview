defmodule SMWeb.Components.Organizations.Show do
  @moduledoc """
  Organization display component.
  """
  use Surface.LiveComponent

  require Logger

  alias SM.Organizations
  alias SMWeb.Components.Dialog

  data show, :boolean, default: false
  data organization, :struct

  # Public API

  def show(dialog_id, organization_id) do
    case Organizations.get(organization_id) do
      {:ok, organization} ->
        send_update(__MODULE__, id: dialog_id, organization: organization, show: true)

      {:error, reason} = error ->
        Logger.error("Error showing Show modal: #{inspect(reason)}")
        error
    end
  end

  # Event handlers

  def handle_event("show", _, socket) do
    socket =
      socket
      |> assign(show: true)

    {:noreply, socket}
  end

  def handle_event("hide", _, socket) do
    socket =
      socket
      |> assign(show: false)
      |> push_patch(to: "/organizations")

    {:noreply, socket}
  end

  # Internal

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
