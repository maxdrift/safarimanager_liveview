defmodule SMWeb.Components.Dialog do
  @moduledoc """
  Dialog component
  """
  use SMWeb, :component

  attr :id, :string, required: true
  attr :show, :boolean, default: false

  slot :default, required: true

  def dialog(assigns) do
    ~H"""
    <div
      id={@id}
      class={["modal", @show && "modal-open"]}
      phx-window-keydown="hide"
      phx-key="Escape"
      phx-target={"#" <> @id}
    >
      <div :if={@show} class="modal-box">
        {render_slot(@default)}
      </div>
    </div>
    """
  end
end
