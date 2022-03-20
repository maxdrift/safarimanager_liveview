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
  prop reset_label, :string, default: "Reset"
  prop submit_label, :string, default: "Save"
end
