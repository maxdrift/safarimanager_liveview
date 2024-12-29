defmodule SMWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use PhoenixHTMLHelpers

  alias Phoenix.HTML.Form

  @doc """
  Generates tag for inlined form input errors.
  """
  @spec error_tag(Form.t(), atom(), Keyword.t()) :: {:safe, list()}
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

  @spec input_state_class(Ecto.Changeset.t() | Form.t(), atom(), Keyword.t()) :: String.t()
  def input_state_class(changeset_or_form, field, opts \\ []) do
    opts = Keyword.put(opts, :type, :input)
    state_class("input input-bordered", changeset_or_form, field, opts)
  end

  @spec select_state_class(Ecto.Changeset.t() | Form.t(), atom(), Keyword.t()) :: String.t()
  def select_state_class(changeset_or_form, field, opts \\ []) do
    opts = Keyword.put(opts, :type, :select)
    state_class("select select-bordered", changeset_or_form, field, opts)
  end

  @spec state_class(String.t(), Ecto.Changeset.t() | Form.t(), atom(), Keyword.t()) :: String.t()
  def state_class(class, changeset, field, opts \\ [])

  def state_class(class, %Ecto.Changeset{} = changeset, field, opts) do
    input_type = Keyword.get(opts, :type, :input)

    class =
      cond do
        # no state checking
        opts[:no_state] -> class
        # The form was not yet submitted
        !changeset.action -> class
        changeset.errors[field] -> "#{class} #{input_type}-error"
        true -> "#{class} #{input_type}-success"
      end

    String.trim(class)
  end

  def state_class(class, %Form{} = form, field, opts) do
    input_type = Keyword.get(opts, :type, :input)

    class =
      cond do
        # no state checking
        opts[:no_state] -> class
        # The form was not yet submitted
        !form.source.action && !form.action -> class
        form.source.errors[field] -> "#{class} #{input_type}-error"
        true -> "#{class} #{input_type}-success"
      end

    String.trim(class)
  end

  @spec submit_state_class(String.t(), Ecto.Changeset.t() | Form.t(), Keyword.t()) :: String.t()
  def submit_state_class(class \\ "btn btn-md", changeset, opts \\ [])

  def submit_state_class(class, %Ecto.Changeset{} = changeset, opts) do
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

  def submit_state_class(class, %Form{} = form, opts) do
    class =
      cond do
        # no state checking
        opts[:no_state] -> class
        # The form was submitted and is valid
        form.source.action && form.source.valid? -> "#{class} btn-success"
        # The form was not yet submitted or is not valid
        !(form.source.action && form.source.valid?) -> "#{class} btn-disabled"
        true -> class
      end

    String.trim(class)
  end
end
