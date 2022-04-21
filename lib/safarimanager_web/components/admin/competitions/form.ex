defmodule SMWeb.Components.Admin.Competitions.Form do
  @moduledoc """
  Competitions form component.
  """
  use SMWeb, :surface_component

  alias Surface.Components.Form
  alias Surface.Components.Form.DateTimeLocalInput
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.NumberInput
  alias Surface.Components.Form.TextInput

  prop action, :atom, values!: [:create, :edit]
  prop entity, :struct, required: true
  prop changeset, :changeset, required: true
  prop validate, :event, required: true
  prop submit, :event, required: true
  prop redirect_to, :string

  slot default, required: true
end
