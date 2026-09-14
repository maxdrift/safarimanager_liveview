defmodule SMWeb.Components.JuryToolbarButton do
  @moduledoc """
  Jury toolbar button component
  """
  use SMWeb, :component

  attr :id, :string
  attr :click, :string
  attr :click_key, :string
  attr :click_value, :string
  attr :title, :string
  attr :class, :any, default: "btn btn-sm"

  slot :inner_block

  def jury_toolbar_button(%{click: click} = assigns) when is_binary(click) do
    phx_value_attrs =
      case assigns do
        %{click_key: key, click_value: value} when is_binary(key) and not is_nil(value) ->
          %{"phx-value-#{key}" => value}

        _ ->
          %{}
      end

    assigns = assign(assigns, :phx_value_attrs, phx_value_attrs)

    ~H"""
    <button
      id={@id}
      phx-click={@click}
      {@phx_value_attrs}
      class={@class}
      title={@title}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  def jury_toolbar_button(assigns) do
    ~H"""
    <button id={@id} class={@class} title={@title}>
      {render_slot(@inner_block)}
    </button>
    """
  end
end
