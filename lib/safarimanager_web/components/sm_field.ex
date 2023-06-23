defmodule SMWeb.Components.SMField do
  @moduledoc """
  Custom form field static component
  """

  use SMWeb, :surface_component

  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label

  prop name, :string, required: true
  prop label, :string
  prop class, :css_class, default: []

  slot default, required: true

  def render(assigns) do
    ~F"""
    <Field name={@name} class={["form-control" | @class]}>
      <Label :if={@label} class="label">
        <span class="label-text">{@label}</span>
      </Label>
      <#slot />
      <Label class="label h-7">
        <ErrorTag />
      </Label>
    </Field>
    """
  end
end
