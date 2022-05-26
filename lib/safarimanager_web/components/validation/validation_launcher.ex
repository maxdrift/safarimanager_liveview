defmodule SMWeb.ValidationLauncher do
  @moduledoc """
  Validation launcher live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Slides
  alias SM.Subjects
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Link
  alias Surface.Components.LiveRedirect

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:flagged_slides, [])
      |> assign(:subjects, Subjects.list())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    {:ok, competition} = Competitions.get(competition_id)

    flagged_slides = Slides.list_flagged(competition_id)
    duplicate_subjects = Slides.list_duplicate_subjects(competition_id)
    over_submitted_threshold = Slides.list_over_submitted_threshold(competition_id)

    over_jury_threshold =
      if competition.settings.proportional_submission do
        Slides.list_over_proportional_jury_threshold(competition_id)
      else
        Slides.list_over_static_jury_threshold(competition_id)
      end

    stats =
      competition_id
      |> Slides.list_stats_by_participant()
      |> Enum.reduce(%{}, fn {participant_number, p_stats}, acc ->
        new_stats =
          acc
          |> Map.get(participant_number, %{})
          |> Map.merge(p_stats)
          |> Map.put_new(:submitted_jury, 0)
          |> Map.put_new(:submitted_fixed, 0)

        Map.put(acc, participant_number, new_stats)
      end)
      |> Enum.map(fn {participant_number, stats} ->
        flagged_slides =
          Enum.flat_map(flagged_slides, fn
            {^participant_number, slide} -> [slide]
            {_participant_number, _slide} -> []
          end)

        duplicate_subjects =
          Enum.flat_map(duplicate_subjects, fn
            {^participant_number, slide, count} -> [{slide, count}]
            {_participant_number, _slide, _count} -> []
          end)

        over_submitted_threshold =
          Enum.flat_map(over_submitted_threshold, fn
            {^participant_number, count} -> [count]
            {_participant_number, _count} -> []
          end)

        over_jury_threshold =
          Enum.flat_map(over_jury_threshold, fn
            {^participant_number, count} -> [count]
            {_participant_number, _count} -> []
          end)

        new_stats =
          Map.merge(stats, %{
            flagged_slides: flagged_slides,
            duplicate_subjects: duplicate_subjects,
            over_submitted_threshold: over_submitted_threshold,
            over_jury_threshold: over_jury_threshold
          })

        {participant_number, new_stats}
      end)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:stats, stats)

    {:noreply, socket}
  end

  # Internal

  defp subject_name(subjects, subject_id) do
    Enum.find_value(subjects, "N/A", fn s ->
      if s.id == subject_id, do: s.name
    end)
  end

  defp status_to_label(:submitted_fixed), do: "Fixed points"
  defp status_to_label(:submitted_jury), do: "Jury"

  defp list_to_boolean([]), do: false
  defp list_to_boolean([_ | _]), do: true

  defp over_jury_th_tooltip(%{over_jury_threshold: [value]} = stats, competition) do
    if competition.settings.proportional_submission do
      total = Decimal.add(stats.submitted_jury, stats.submitted_fixed)
      threshold = Decimal.mult(total, competition.settings.submission_ratio)
      "#{value}/#{threshold}"
    else
      "#{value}/#{competition.settings.max_jury_slides}"
    end
  end

  defp over_jury_th_tooltip(%{} = stats, competition) do
    if competition.settings.proportional_submission do
      total = Decimal.add(stats.submitted_jury, stats.submitted_fixed)
      threshold = Decimal.mult(total, competition.settings.submission_ratio)
      "#{stats.submitted_jury}/#{threshold}"
    else
      "#{stats.submitted_jury}/#{competition.settings.max_jury_slides}"
    end
  end
end
