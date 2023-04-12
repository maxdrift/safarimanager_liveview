defmodule SMWeb.Components.Admin.Organizations.Merge do
  @moduledoc """
  Merge entity Live Component.
  """
  use SMWeb, :surface_live_component

  alias SMWeb.Components.Dialog
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.Select

  require Logger

  data show, :boolean, default: false

  prop source_entities, :map, required: true
  prop items, :map, required: true
  prop changeset, :changeset, required: true
  prop validate, :event, required: true
  prop submit, :event, required: true
  prop redirect_to, :string, required: true
  prop entity_name, :string, required: true

  # Public API

  @spec show(String.t()) :: any()
  def show(dialog_id) do
    send_update(__MODULE__,
      id: dialog_id,
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
