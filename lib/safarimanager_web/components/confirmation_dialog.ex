defmodule SMWeb.Components.ConfirmationDialog do
  @moduledoc """
  Confirmation dialog component.
  """
  use Surface.LiveComponent

  alias SMWeb.Components.Dialog

  data show, :boolean, default: false

  slot default, required: true

  # Public API

  def show(dialog_id) do
    send_update(__MODULE__, id: dialog_id, show: true)
  end

  def hide(dialog_id) do
    send_update(__MODULE__, id: dialog_id, show: false)
  end

  # Event handlers

  def handle_event("show", _, socket) do
    {:noreply, assign(socket, show: true)}
  end

  def handle_event("hide", _, socket) do
    {:noreply, assign(socket, show: false)}
  end
end
