defmodule SM.CSVImport do
  @moduledoc """
  CSV import context
  """

  use SM, :context

  alias SM.Accounts
  alias SM.Categories
  alias SM.Competitions
  alias SM.Evaluations
  alias SM.Jurors
  alias SM.Organizations
  alias SM.Participants
  alias SM.Slides
  alias SM.Subjects
  alias SM.Utils.CSVHelper

  @spec import(String.t(), String.t()) :: %{
          success: non_neg_integer(),
          failure: non_neg_integer()
        }
  def import("users", path) do
    do_import(Accounts, path)
  end

  def import("organizations", path) do
    do_import(Organizations, path)
  end

  def import("categories", path) do
    do_import(Categories, path)
  end

  def import("subjects", path) do
    do_import(Subjects, path)
  end

  def import("evaluations", path) do
    do_import(Evaluations, path)
  end

  def import("jurors", path) do
    do_import(Jurors, path)
  end

  def import("participants", path) do
    do_import(Participants, path)
  end

  def import("competitions", path) do
    do_import(Competitions, path)
  end

  def import("slides", path) do
    do_import(Slides, path)
  end

  # Internal

  defp do_import(context, path) do
    path
    |> CSVHelper.csv_to_stream(skip_headers: false)
    |> Stream.transform([], fn
      r, [] -> {[], r}
      r, acc -> {[acc |> Enum.zip(r) |> Map.new()], acc}
    end)
    |> Stream.scan(%{success: 0, failure: 0}, fn row, acc ->
      row
      |> context.import()
      |> case do
        {:ok, _record} ->
          %{acc | success: acc.success + 1}

        {:error, changeset} ->
          Logger.error(
            "Unable to import row '#{row["id"]}' into #{inspect(context)}:\n#{changeset_error_to_string(changeset)}"
          )

          %{acc | failure: acc.failure + 1}
      end
    end)
    |> Enum.reverse()
    |> hd()
  end

  defp changeset_error_to_string(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.reduce("", fn {k, v}, acc ->
      joined_errors = Enum.join(v, "; ")
      "#{acc}#{k}: #{joined_errors}\n"
    end)
  end
end
