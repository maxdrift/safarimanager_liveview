defmodule SMWeb.Components.Competitions.Edit do
  @moduledoc """
  Edit entity Live Component.
  """
  use SMWeb, :surface_live_component

  alias SMWeb.Components.Competitions.Form
  alias SMWeb.Components.Dialog
  alias SMWeb.Components.FormActions

  data show, :boolean, default: false
  data action, :atom, values!: [:create, :edit]

  prop entity, :struct, required: true
  prop changeset, :changeset, required: true
  prop validate, :event, required: true
  prop submit, :event, required: true
  prop redirect_to, :string, required: true
  prop entity_name, :string, required: true

  # Public API

  @spec show(String.t(), :create | :edit) :: any()
  def show(dialog_id, action) when action in [:create, :edit] do
    send_update(__MODULE__,
      id: dialog_id,
      action: action,
      show: true
    )
  end

  @spec hide(String.t()) :: any()
  def hide(dialog_id) do
    send_update(__MODULE__, id: dialog_id, show: false)
  end

  # Event handlers

  @impl Phoenix.LiveComponent
  def handle_event("hide", _value, socket) do
    socket =
      socket
      |> assign(show: false)
      |> push_patch(to: socket.assigns.redirect_to)

    {:noreply, socket}
  end
end
