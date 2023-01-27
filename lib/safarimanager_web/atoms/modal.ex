defmodule SMWeb.Components.Modal do
  @moduledoc """
  Modal component
  """
  use SMWeb, :surface_live_component

  prop on_confirm, :event
  prop on_cancel, :event, default: "hide"

  data show, :boolean, default: false

  slot default, required: true
  slot title
  slot confirm
  slot cancel

  def render(assigns) do
    ~F"""
    <div
      id={@id}
      class={"modal", "modal-open": @show}
      :on-window-keydown="hide"
      phx-key="Escape"
      phx-target={"#" <> @id}
    >
      <div :if={@show} class="modal-box">
        <div class="absolute top-6 right-5">
          <button
            :on-click={@on_cancel}
            type="button"
            class="-m-3 red flex-none p-3 opacity-20 hover:opacity-40"
          >
            <Heroicons.Surface.Icon name="x-mark" type="solid" class="h-5 w-5 stroke-current" />
          </button>
        </div>
        <div :if={slot_assigned?(:title)} class="card-title">
          <#slot {@title} />
        </div>
        <div class="card-body">
          <#slot />
        </div>
        <div :if={slot_assigned?(:confirm) or slot_assigned?(:cancel)} class="modal-action">
          <button :if={slot_assigned?(:confirm)} :on-click={@on_confirm}>
            <#slot {@confirm} />
          </button>
          <button :if={slot_assigned?(:cancel)} :on-click={@on_cancel}>
            <#slot {@cancel} />
          </button>
        </div>
      </div>
    </div>
    """
  end

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
