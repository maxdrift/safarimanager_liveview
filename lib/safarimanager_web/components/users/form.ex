defmodule SMWeb.Components.Users.Form do
  @moduledoc """
  User form component.
  """
  use SMWeb, :surface_component

  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.FieldContext
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.TextInput

  prop action, :atom, values!: [:create, :edit]
  prop entity, :struct, required: true
  prop changeset, :changeset, required: true
  prop validate, :event, required: true
  prop submit, :event, required: true
  prop redirect_to, :string
  prop organizations, :list, default: []

  slot default, required: true
end
