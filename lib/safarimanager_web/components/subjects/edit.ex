defmodule SMWeb.Components.Subjects.Edit do
  @moduledoc """
  Edit entity Live Component.
  """
  use SMWeb, :surface_live_component

  alias SM.Subjects
  alias SMWeb.Components.Dialog
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.NumberInput
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput

  require Logger

  data show, :boolean, default: false
  data action, :atom, values!: [:create, :edit]
  data subject_types, :list, default: Subjects.list_subject_types()
  data coefficients, :list, default: Subjects.list_subject_coefficients()

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
