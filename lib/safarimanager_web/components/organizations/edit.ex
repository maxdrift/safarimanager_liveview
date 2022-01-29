defmodule SMWeb.Components.Organizations.Edit do
  @moduledoc """
  Edit entity Live Component.
  """
  use Surface.LiveComponent

  require Logger

  alias SMWeb.Components.Dialog
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput

  data show, :boolean, default: false
  data action, :atom, values!: [:create, :edit]

  prop entity, :struct, required: true
  prop changeset, :changeset, required: true
  prop validate, :event, required: true
  prop submit, :event, required: true
  prop redirect_to, :string, required: true
  prop entity_name, :string, required: true

  # Public API

  def show(dialog_id, action) when action in [:create, :edit] do
    send_update(__MODULE__,
      id: dialog_id,
      action: action,
      show: true
    )
  end

  def hide(dialog_id) do
    send_update(__MODULE__, id: dialog_id, show: false)
  end

  # Event handlers

  def handle_event("hide", _, socket) do
    socket =
      socket
      |> assign(show: false)
      |> push_patch(to: socket.assigns.redirect_to)

    {:noreply, socket}
  end
end
