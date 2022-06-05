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

  @spec list(String.t()) :: {:ok, [Subject.t()]} | {:error, :not_found}
  def list(competition_id) do
    {:ok, competition} = Competitions.get(competition_id)

    subjects_map =
      competition_id
      |> Subjects.list_with_coefficients()
      |> Enum.into(%{}, fn subject ->
        {subject.id, subject}
      end)

    {results, _acc} =
      Participants.list(competition_id)
      |> Enum.map(fn participant ->
        {slides, total_score} =
          list_by_participant(competition_id, competition, participant.user.id, subjects_map)

        %{
          participant: participant,
          user: participant.user,
          slides: slides,
          total_score: total_score
        }
      end)
      |> Enum.sort(&(Decimal.compare(&1.total_score, &2.total_score) in [:gt, :eq]))
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
