defmodule SM.Results do
  @moduledoc """
  The Results context.
  """
  use SM, :context

  alias SM.Competitions
  alias SM.Slides
  alias SM.Slides.Slide

  @fixed_score 5

  @spec list(String.t()) :: {:ok, [%{atom() => any()}]} | {:error, :not_found}
  def list(competition_id) do
    with {:ok, competition} <- Competitions.get(competition_id) do
      {results, _acc} =
        competition.participants
        |> Enum.map(fn participant ->
          {slides, total_score} = list_by_participant(competition_id, participant.id)
          %{user: participant, slides: slides, total_score: total_score}
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
  end

  @spec list_by_participant(String.t(), String.t()) :: {[%{atom() => any()}], Decimal.t()}
  def list_by_participant(competition_id, user_id) do
    Enum.flat_map_reduce(Slides.list(user_id, competition_id), Decimal.new(0), fn
      %Slide{status: :submitted_jury} = slide, total_score ->
        slide_score =
          Decimal.mult(
            Enum.reduce(slide.evaluations, Decimal.new(0), &Decimal.add(&2, &1.value)),
            Decimal.new(slide.subject.coefficient)
          )

        {[%{slide: slide, slide_score: slide_score}], Decimal.add(total_score, slide_score)}

      %Slide{status: :submitted_fixed} = slide, total_score ->
        slide_score =
          Decimal.mult(Decimal.new(@fixed_score), Decimal.new(slide.subject.coefficient))

        {[%{slide: slide, slide_score: slide_score}], Decimal.add(total_score, slide_score)}

      %Slide{}, total_score ->
        {[], total_score}
    end)
  end
end
