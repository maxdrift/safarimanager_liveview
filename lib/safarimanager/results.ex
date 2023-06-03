defmodule SM.Results do
  @moduledoc """
  The Results context.
  """
  use SM, :context

  alias SM.Competitions
  alias SM.Competitions.Competition
  alias SM.Participants
  alias SM.Slides
  alias SM.Slides.Slide
  alias SM.Subjects
  alias SM.Subjects.Subject

  @spec list(String.t()) :: {:ok, [Subject.t()]} | {:error, :not_found}
  def list(competition_id) do
    with {:ok, competition} <- Competitions.get(competition_id) do
      subjects_map =
        competition_id
        |> Subjects.list_with_coefficients()
        |> Enum.into(%{}, fn subject ->
          {subject.id, subject}
        end)

      unique_coefficients =
        Enum.reduce(subjects_map, MapSet.new(), fn {_key, s}, acc ->
          MapSet.put(acc, s.coefficient)
        end)
        |> MapSet.to_list()
        |> Enum.sort({:desc, Decimal})

      {results, _acc} =
        Participants.list(competition_id)
        |> Stream.map(fn participant ->
          {slides, total_score} =
            list_by_participant(competition_id, competition, participant.user.id, subjects_map)

          %{
            participant: participant,
            user: participant.user,
            slides: slides,
            slides_count: Enum.count(slides),
            total_score: total_score
          }
        end)
        |> Stream.map(fn result ->
          coefficients_count = Enum.frequencies_by(result.slides, & &1.coefficient)

          Map.put(result, :coefficients_count, coefficients_count)
        end)
        |> Enum.sort_by(
          &List.to_tuple([by_score(&1), by_slides(&1) | by_coefficients(&1, unique_coefficients)]),
          :desc
        )
        |> Enum.map_reduce({0, 0, Decimal.new("Infinity")}, fn %{total_score: score} = result,
                                                               {prev_index, prev_rank, prev_score} ->
          if Decimal.compare(score, prev_score) == :lt do
            new_index = prev_index + 1
            new_rank = prev_index + 1
            {Map.put(result, :rank, new_rank), {new_index, new_rank, score}}
          else
            {Map.put(result, :rank, prev_rank), {prev_index + 1, prev_rank, score}}
          end
        end)

      {:ok, results}
    end
  end

  defp by_score(result),
    do: result.total_score

  defp by_slides(result),
    do: result.slides_count

  defp by_coefficients(result, coefficients) do
    Enum.map(coefficients, fn c ->
      Map.get(result.coefficients_count, c, 0)
    end)
  end

  @spec list_by_participant(String.t(), Competition.t(), String.t(), %{
          Ecto.UUID.t() => Decimal.t()
        }) ::
          {[%{atom() => any()}], Decimal.t()}
  def list_by_participant(competition_id, competition, user_id, subjects_map) do
    user_id
    |> Slides.list_for_results(competition_id)
    |> Enum.flat_map_reduce(Decimal.new(0), fn
      %Slide{penalty: true} = slide, total_score ->
        subject = Map.fetch!(subjects_map, slide.subject_id)

        slide_score = competition.settings.penalty_amount

        {[%{slide: slide, slide_score: slide_score, coefficient: subject.coefficient}],
         Decimal.add(total_score, slide_score)}

      %Slide{status: :submitted_jury} = slide, total_score ->
        subject = Map.fetch!(subjects_map, slide.subject_id)

        slide_score =
          Decimal.mult(
            Enum.reduce(slide.evaluations, Decimal.new(0), &Decimal.add(&2, &1.value)),
            subject.coefficient
          )

        {[%{slide: slide, slide_score: slide_score, coefficient: subject.coefficient}],
         Decimal.add(total_score, slide_score)}

      %Slide{status: :submitted_fixed} = slide, total_score ->
        subject = Map.fetch!(subjects_map, slide.subject_id)

        slide_score =
          Decimal.mult(competition.settings.fixed_points_multiplier, subject.coefficient)

        {[%{slide: slide, slide_score: slide_score, coefficient: subject.coefficient}],
         Decimal.add(total_score, slide_score)}

      %Slide{}, total_score ->
        {[], total_score}
    end)
  end
end
