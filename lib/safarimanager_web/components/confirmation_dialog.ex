defmodule SMWeb.Components.ConfirmationDialog do
  @moduledoc """
  Confirmation dialog component.
  """
  use SMWeb, :surface_live_component

  alias SMWeb.Components.Dialog

  data show, :boolean, default: false

  slot default, required: true

  # Public API

  @spec show(String.t()) :: any()
  def show(dialog_id) do
    send_update(__MODULE__, id: dialog_id, show: true)
  end

  @spec hide(String.t()) :: any()
  def hide(dialog_id) do
    send_update(__MODULE__, id: dialog_id, show: false)
  end

  # Event handlers

  @impl Phoenix.LiveComponent
  def handle_event("show", _value, socket) do
    {:noreply, assign(socket, show: true)}
  end

  def handle_event("hide", _value, socket) do
    {:noreply, assign(socket, show: false)}
  end
end
