defmodule SM.CSVExport do
  @moduledoc """
  CSV export context
  """

  use SM, :context

  alias SM.Accounts.User
  alias SM.Categories.Category
  alias SM.Competitions.Competition
  alias SM.Competitions.CompetitionSettings
  alias SM.Evaluations.Evaluation
  alias SM.Jurors.Juror
  alias SM.Organizations.Organization
  alias SM.Participants.Participant
  alias SM.Slides.Slide
  alias SM.Slides.SlideEvaluation
  alias SM.Slides.SlideFlag
  alias SM.Subjects.Subject
  alias SM.Utils.CSVHelper

  @spec export(String.t(), fun()) :: any()
  def export("users", callback) when is_function(callback) do
    extra_fields = %{hashed_password: fn _row -> nil end}

    do_export(User, callback, extra_fields: extra_fields)
  end

  def export("organizations", callback) when is_function(callback) do
    do_export(Organization, callback)
  end

  def export("categories", callback) when is_function(callback) do
    do_export(Category, callback)
  end

  def export("subjects", callback) when is_function(callback) do
    do_export(Subject, callback)
  end

  def export("evaluations", callback) when is_function(callback) do
    do_export(Evaluation, callback)
  end

  def export("jurors", callback) when is_function(callback) do
    do_export(Juror, callback)
  end

  def export("competitions", callback) when is_function(callback) do
    extra_fields = %{
      settings: fn row ->
        CompetitionSettings
        |> Repo.get_by(competition_id: row.id)
        |> Jason.encode!()
      end,
      allowed_evaluations: fn row ->
        "competitions_evaluations"
        |> from()
        |> where(competition_id: ^row.id)
        |> select([ce], ce.evaluation_id)
        |> Repo.all()
        |> Jason.encode!()
      end
    }

    do_export(Competition, callback, extra_fields: extra_fields)
  end

  def export("slides", callback) when is_function(callback) do
    extra_fields = %{
      metadata: fn row -> Jason.encode!(row.metadata) end,
      slide_flags: fn row ->
        query = from(sf in SlideFlag, where: [slide_id: ^row.id])

        query
        |> Repo.all()
        |> Jason.encode!()
      end,
      evaluations: fn row ->
        query =
          from(se in SlideEvaluation,
            where: [slide_id: ^row.id],
            select: [se.user_id, se.evaluation_id]
          )

        query
        |> Repo.all()
        |> Jason.encode!()
      end
    }

    do_export(Slide, callback, extra_fields: extra_fields)
  end

  def export("participants", callback) when is_function(callback) do
    do_export(Participant, callback)
  end

  defp do_export(model, callback, opts \\ []) do
    fields = model.__schema__(:fields)

    extra_fields = Keyword.get(opts, :extra_fields, %{})
    extra_keys = Map.keys(extra_fields)

    final_fields = Enum.uniq(fields ++ extra_keys)

    transaction =
      Repo.transaction(
        fn ->
          model
          |> from()
          |> select([u], map(u, ^fields))
          |> Repo.stream()
          |> Stream.map(&stream_row(&1, extra_fields, final_fields))
          |> CSVHelper.stream_to_csv(final_fields)
          |> Stream.scan({:error, :unknown}, fn row, _acc ->
            callback.(row)
          end)
          |> Enum.reverse()
          |> hd()
        end,
        timeout: :infinity
      )

    case transaction do
      {:ok, result} -> result
      {:error, reason} -> reason
    end
  end

  defp stream_row(row, extra_fields, final_fields) do
    extra_fields =
      Map.new(extra_fields, fn {key, fun} -> {key, fun.(row)} end)

    row = Map.merge(row, extra_fields)
    row_map_to_list(row, final_fields)
  end

  defp row_map_to_list(row_map, fields) do
    Enum.map(fields, fn field ->
      Map.get(row_map, field)
    end)
  end
end
