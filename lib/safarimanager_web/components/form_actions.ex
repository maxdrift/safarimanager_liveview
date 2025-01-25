defmodule SMWeb.Components.FormActions do
  @moduledoc """
  Form actions component.
  """
  use SMWeb, :component

  import PhoenixHTMLHelpers.Form, only: [reset: 2, submit: 2]

  attr :container_class, :string
  attr :enable_submit, :boolean, default: true
  attr :reset, :string, required: true
  attr :reset_label, :string, default: gettext("Reset")
  attr :submit_label, :string, default: gettext("Save")

  def form_actions(assigns) do
    ~H"""
    <div class={@container_class}>
      {submit(@submit_label,
        class: [
          "btn btn-md",
          @enable_submit && "btn-success",
          !@enable_submit && "btn-disabled"
        ]
      )}
      {reset(@reset_label, class: "btn btn-md btn-ghost", phx_click: @reset)}
    </div>
    """
  end
end
