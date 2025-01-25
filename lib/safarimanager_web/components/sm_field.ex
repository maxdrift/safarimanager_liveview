defmodule SMWeb.Components.SMField do
  @moduledoc """
  Custom form field static component
  """

  use SMWeb, :component

  alias Phoenix.HTML.FormField

  attr :id, :any, default: nil
  attr :name, :string
  attr :label, :string, default: nil
  attr :field, FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]"
  attr :class, :list, default: []
  attr :errors, :list, default: []

  slot :inner_block, required: true

  def sm_field(%{field: %FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> sm_field()
  end

  def sm_field(assigns) do
    ~H"""
    <div name={@name} class={["form-control" | @class]}>
      <.label for={@name} class={["label"]}>
        <span :if={@label} class="label-text">{@label}</span>
      </.label>
      {render_slot(@inner_block)}
      <.label class={["label h-7"]}>
        <.error :for={msg <- @errors}>{msg}</.error>
      </.label>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  attr :class, :list, default: []
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={@class}>
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600">
      <Heroicons.icon name="exclamation-circle" type="mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end
end
