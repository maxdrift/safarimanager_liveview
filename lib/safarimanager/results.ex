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
  alias SM.Subjects.Subject

  @spec list(String.t()) :: {:ok, [%{atom() => any()}]} | {:error, :not_found}
  def list(competition_id) do
    {:ok, competition} = Competitions.get(competition_id)
    subjects = get_all_dynamic_coefficients(competition_id, competition)

    {results, _acc} =
      Participants.list(competition_id)
      |> Enum.map(fn participant ->
        {slides, total_score} =
          list_by_participant(competition_id, competition, participant.user.id, subjects)

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

  @spec list_by_participant(String.t(), Competition.t(), String.t(), [Subject.t()]) ::
          {[%{atom() => any()}], Decimal.t()}
  def list_by_participant(competition_id, competition, user_id, subjects) do
    user_id
    |> Slides.list(competition_id)
    |> Enum.flat_map_reduce(Decimal.new(0), fn
      # TODO: Detect penalty and skip sum of evaluations
      %Slide{status: :submitted_jury} = slide, total_score ->
        subject = Enum.find(subjects, &(&1.id == slide.subject_id))

        slide_score =
          Decimal.mult(
            Enum.reduce(slide.evaluations, Decimal.new(0), &Decimal.add(&2, &1.value)),
            Decimal.mult(subject.coefficient, subject.dynamic_coefficient)
          )

        {[%{slide: slide, slide_score: slide_score}], Decimal.add(total_score, slide_score)}

      %Slide{status: :submitted_fixed} = slide, total_score ->
        slide_score =
          Decimal.mult(
            competition.settings.fixed_points_multiplier,
            Decimal.new(slide.subject.coefficient)
          )

        {[%{slide: slide, slide_score: slide_score}], Decimal.add(total_score, slide_score)}

      %Slide{}, total_score ->
        {[], total_score}
    end)
  end

  @spec get_all_dynamic_coefficients(String.t(), Competition.t()) :: [Subject.t()]
  def get_all_dynamic_coefficients(competition_id, competition) do
    coefficients =
      competition
      |> Map.fetch!(:settings)
      |> Map.fetch!(:dynamic_coefficients)
      |> Enum.sort(fn left, right ->
        Decimal.compare(left.from, right.from) in [:lt, :eq] and
          Decimal.compare(left.to, right.to) in [:lt]
      end)

    competition_id
    |> Slides.subjects_distribution()
    |> Enum.map(fn subject ->
      matches =
        Enum.flat_map(coefficients, fn coeff ->
          if between(coeff.from, subject.distribution, coeff.to) do
            [coeff.value]
          else
            []
          end
        end)

      coeff =
        case matches do
          [] ->
            # TODO: Fail and return an error to the UI
            Logger.error(
              "Dynamic coefficients enabled but invalid intervals for #{inspect(subject.distribution)}"
            )

            Decimal.new(1)

          [match] ->
            match

          [match | _] ->
            # TODO: Fail and return an error to the UI
            Logger.warning("Dynamic coefficients config has overlapping intervals")
            match
        end

      Map.put(subject, :dynamic_coefficient, coeff)
    end)
  end

  defp between(%Decimal{} = left, %Decimal{} = center, %Decimal{} = right) do
    Decimal.compare(center, left) == :gt and Decimal.compare(center, right) in [:lt, :eq]
  end
end
