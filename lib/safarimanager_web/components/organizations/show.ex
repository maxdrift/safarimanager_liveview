defmodule SMWeb.Components.Organizations.Show do
  @moduledoc """
  Display entity Live Component.
  """
  use Surface.LiveComponent

  alias SMWeb.Components.Dialog

  data show, :boolean, default: false
  data entity, :struct

  prop redirect_to, :string, required: true
  prop entity_name, :string, required: true

  # Public API

  def show(dialog_id, entity) do
    send_update(__MODULE__, id: dialog_id, entity: entity, show: true)
  end

  # Event handlers

  def handle_event("hide", _, socket) do
    socket =
      socket
      |> assign(show: false)
      |> push_patch(to: socket.assigns.redirect_to)

    {:noreply, socket}
  end

  # Internal

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
