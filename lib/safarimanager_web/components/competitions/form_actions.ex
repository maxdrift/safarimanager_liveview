defmodule SMWeb.Components.Competitions.FormActions do
  @moduledoc """
  Competitions form actions component.
  """
  use Surface.Component

  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Submit

  prop container_class, :css_class
  prop submit_enabled?, :boolean, required: true
  prop reset, :event, required: true
end
