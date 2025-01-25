# defmodule SMWeb.Live.Admin.Competitions.Form do
#   @moduledoc """
#   Competitions form component.
#   """
#   use SMWeb, :surface_component

#   alias Surface.Components.Context
#   alias Surface.Components.Form
#   alias Surface.Components.Form.Checkbox
#   alias Surface.Components.Form.DateTimeLocalInput
#   alias Surface.Components.Form.ErrorTag
#   alias Surface.Components.Form.Field
#   alias Surface.Components.Form.HiddenInput
#   alias Surface.Components.Form.Inputs
#   alias Surface.Components.Form.Label
#   alias Surface.Components.Form.NumberInput
#   alias Surface.Components.Form.Select
#   alias Surface.Components.Form.TextInput

#   prop id, :string, required: true
#   prop action, :atom, values!: [:create, :edit]
#   prop competition_types, :list, required: true
#   prop entity, :struct, required: true
#   prop changeset, :changeset, required: true
#   prop validate, :event, required: true
#   prop submit, :event, required: true
#   prop redirect_to, :string
#   prop organizations, :list, required: true
#   prop evaluations, :list, required: true
#   prop coefficient_modes, :list, required: true
#   prop dynamic_coefficient_modes, :list, required: true

#   slot default, required: true
# end
