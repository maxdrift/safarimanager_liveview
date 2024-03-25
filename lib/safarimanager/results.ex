defmodule SM.Results do
  @moduledoc """
  The Results context.
  """
  use SM, :context

  alias SM.Competitions
  alias SM.Participants
  alias SM.Slides
  alias SM.Slides.Slide
  alias SM.Subjects
  alias SM.Teams

  @spec list(String.t(), String.t() | nil) :: {:ok, map()} | {:error, any()}
  def list(competition_id, category_id \\ nil) do
    with {:ok, competition} <- Competitions.get(competition_id) do
      {subjects_map, unique_coefficients} = extract_subjects_and_coefficients(competition_id)

      {results, _acc} =
        competition_id
        |> Participants.list(category_id)
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

  @spec list_for_teams(String.t()) :: {:ok, map()} | {:error, any()}
  def list_for_teams(competition_id) do
    with {:ok, competition} <- Competitions.get(competition_id) do
      {subjects_map, unique_coefficients} = extract_subjects_and_coefficients(competition_id)

      {results, _acc} =
        competition_id
        |> Teams.list_by_competition()
        |> Stream.map(fn team ->
          {slides, total_score} =
            team.users
            |> Enum.map(fn user ->
              {:ok, participant} = Participants.get(user.id, competition_id)
              participant
            end)
            |> Enum.reduce({[], 0}, fn participant, {slides_acc, total_score_acc} ->
              {slides, total_score} = list_by_participant(competition_id, competition, participant.user.id, subjects_map)
              {slides_acc ++ slides, Decimal.add(total_score_acc, total_score)}
            end)

          slides =
            slides
            |> Enum.sort_by(& &1.slide.file_name, :asc)
            |> Enum.sort_by(& &1.slide.status, :desc)

          %{
            team: team,
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

  @spec get_printout_config :: any
  def get_printout_config do
    :safarimanager
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:results_printout)
  end

  defp extract_subjects_and_coefficients(competition_id) do
    subjects_map =
      competition_id
      |> Subjects.list_with_coefficients()
      |> Map.new(fn subject ->
        {subject.id, subject}
      end)

    unique_coefficients =
      subjects_map
      |> Enum.reduce(MapSet.new(), fn {_key, s}, acc ->
        MapSet.put(acc, s.coefficient)
      end)
      |> MapSet.to_list()
      |> Enum.sort({:desc, Decimal})

    {subjects_map, unique_coefficients}
  end

  defp by_score(result), do: result.total_score

  defp by_slides(result), do: result.slides_count

  defp by_coefficients(result, coefficients) do
    Enum.map(coefficients, fn c ->
      Map.get(result.coefficients_count, c, 0)
    end)
  end

  defp list_by_participant(competition_id, competition, user_id, subjects_map) do
    user_id
    |> Slides.list_for_results(competition_id)
    |> Enum.flat_map_reduce(Decimal.new(0), &slide_score(&1, &2, competition, subjects_map))
  end

  # If a slide has penalty its score is determined by the corresponding competition setting "penalty_amount"
  defp slide_score(%Slide{penalty: true} = slide, total_score, competition, subjects_map) do
    subject = Map.fetch!(subjects_map, slide.subject_id)

    use_dynamic? = competition.settings.dynamic_coefficients_enabled

    coefficient =
      if use_dynamic? do
        subject.dynamic_coefficient
      else
        subject.coefficient
      end

    slide_score = competition.settings.penalty_amount

    {[%{slide: slide, slide_score: slide_score, coefficient: coefficient, use_dynamic?: use_dynamic?}],
     Decimal.add(total_score, slide_score)}
  end

  # If a slide is submitted to Jury its score is the sum of the evaluation values multiplied by
  # its coefficient (static or dynamic that is)
  defp slide_score(%Slide{status: :submitted_jury} = slide, total_score, competition, subjects_map) do
    subject = Map.fetch!(subjects_map, slide.subject_id)

    use_dynamic? = competition.settings.dynamic_coefficients_enabled

    coefficient =
      if use_dynamic? do
        subject.dynamic_coefficient
      else
        subject.coefficient
      end

    slide_score =
      Decimal.mult(Enum.reduce(slide.votes, Decimal.new(0), &Decimal.add(&2, &1.evaluation.value)), coefficient)

    {[%{slide: slide, slide_score: slide_score, coefficient: coefficient, use_dynamic?: use_dynamic?}],
     Decimal.add(total_score, slide_score)}
  end

  # If a slide is submitted with fixed points its score is its coefficient multiplied by
  # the corresponding competition setting "fixed_points_multiplier"
  defp slide_score(%Slide{status: :submitted_fixed} = slide, total_score, competition, subjects_map) do
    subject = Map.fetch!(subjects_map, slide.subject_id)

    use_dynamic? = competition.settings.dynamic_coefficients_enabled

    coefficient =
      if use_dynamic? do
        subject.dynamic_coefficient
      else
        subject.coefficient
      end

    slide_score = Decimal.mult(competition.settings.fixed_points_multiplier, coefficient)

    {[%{slide: slide, slide_score: slide_score, coefficient: coefficient, use_dynamic?: use_dynamic?}],
     Decimal.add(total_score, slide_score)}
  end

  defp slide_score(%Slide{}, total_score, _competition, _subjects_map) do
    {[], total_score}
  end
end
