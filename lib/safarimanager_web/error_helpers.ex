defmodule SMWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.
  """
  @spec error_tag(Phoenix.HTML.Form.t(), atom(), Keyword.t()) :: {:safe, list()}
  def error_tag(form, field, opts \\ []) do
    if error = form.errors[field] do
      content_tag(:span, translate_error(error), opts)
    end
  end

  @doc """
  Translates an error message using gettext.
  """
  @spec translate_error({String.t(), Keyword.t()}) :: String.t()
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(SMWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(SMWeb.Gettext, "errors", msg, opts)
    end
  end

  @spec input_state_class(Ecto.Changeset.t(), atom(), Keyword.t()) :: String.t()
  def input_state_class(changeset, field, opts \\ []) do
    state_class("input input-bordered", changeset, field, opts)
  end

  @spec state_class(String.t(), Ecto.Changeset.t(), atom(), Keyword.t()) :: String.t()
  def state_class(class, changeset, field, opts \\ []) do
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

  @spec submit_state_class(String.t(), Ecto.Changeset.t(), Keyword.t()) :: String.t()
  def submit_state_class(class \\ "btn btn-md", changeset, opts \\ []) do
    class =
      cond do
        # no state checking
        opts[:no_state] -> class
        # The form was submitted and is valid
        changeset.action && changeset.valid? -> "#{class} btn-success"
        # The form was not yet submitted or is not valid
        !(changeset.action && changeset.valid?) -> "#{class} btn-disabled"
        true -> class
      end

    String.trim(class)
  end
end
