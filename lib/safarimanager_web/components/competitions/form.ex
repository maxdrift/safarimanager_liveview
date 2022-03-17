defmodule SMWeb.Components.Competitions.Form do
  @moduledoc """
  Competitions form component.
  """
  use Surface.Component

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

  defp state_class(class, changeset, field, opts) do
    class =
      cond do
        # no state checking
        opts[:no_state] -> class
        # The form was not yet submitted
        !changeset.action -> class
        changeset.errors[field] -> "#{class} input-error"
        true -> "#{class} input-success"
      end

    String.trim(class)
  end
end
