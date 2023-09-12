defmodule SMWeb.Components.FormActions do
  @moduledoc """
  Form actions component.
  """
  use SMWeb, :surface_component

  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Submit

  prop container_class, :css_class
  prop submit_enabled?, :boolean, required: true
  prop reset, :event, required: true
  prop reset_label, :string, default: gettext("Reset")
  prop submit_label, :string, default: gettext("Save")

  def render(assigns) do
    ~F"""
    <div class={@container_class}>
      <Submit class={
        "btn btn-md",
        "btn-success": @submit_enabled?,
        "btn-disabled": not @submit_enabled?
      }>{@submit_label}</Submit>
      <Reset click={@reset} class="btn btn-md btn-ghost" value={@reset_label} />
    </div>
    """
  end
end
