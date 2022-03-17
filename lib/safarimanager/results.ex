defmodule SM.Results do
  @moduledoc """
  The Results context.
  """
  use SM, :context

  alias SM.Competitions
  alias SM.Slides
  alias SM.Slides.Slide

  @fixed_points 5

  @spec list(String.t()) :: {:ok, [%{atom() => any()}]} | {:error, :not_found}
  def list(competition_id) do
    with {:ok, competition} <- Competitions.get(competition_id) do
      results =
        competition.participants
        |> Enum.map(fn participant ->
          {slides, total_points} = list_by_participant(competition_id, participant.id)
          %{user: participant, slides: slides, total_points: total_points}
        end)
        |> Enum.sort(&(Decimal.compare(&1.total_points, &2.total_points) in [:gt, :eq]))

      {:ok, results}
    end
  end

  @spec list_by_participant(String.t(), String.t()) :: {[%{atom() => any()}], Decimal.t()}
  def list_by_participant(competition_id, user_id) do
    Enum.flat_map_reduce(Slides.list(user_id, competition_id), Decimal.new(0), fn
      %Slide{status: :submitted_jury} = slide, total_points ->
        slide_points =
          Decimal.mult(
            Enum.reduce(slide.evaluations, Decimal.new(0), &Decimal.add(&2, &1.value)),
            Decimal.new(slide.subject.coefficient)
          )

        {[%{slide: slide, slide_points: slide_points}], Decimal.add(total_points, slide_points)}

      %Slide{status: :submitted_fixed} = slide, total_points ->
        slide_points =
          Decimal.mult(Decimal.new(@fixed_points), Decimal.new(slide.subject.coefficient))

        {[%{slide: slide, slide_points: slide_points}], Decimal.add(total_points, slide_points)}

      %Slide{}, total_points ->
        {[], total_points}
    end)
  end
end
