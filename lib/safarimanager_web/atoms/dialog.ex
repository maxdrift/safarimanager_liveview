defmodule SMWeb.Components.Dialog do
  @moduledoc """
  Dialog component
  """
  use SMWeb, :surface_component

  prop id, :string, required: true

  prop show, :boolean, default: false

  slot default, required: true

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
        <#slot />
      </div>
    </div>
    """
  end
end
