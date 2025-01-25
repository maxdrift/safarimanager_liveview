defmodule SMWeb.Live.ValidationLauncher do
  @moduledoc """
  Validation launcher live view
  """
  use SMWeb, :surface_view

  import SMWeb.Components.CompetitionHeader
  import SMWeb.Components.Layout
  import SMWeb.Components.StepsHeader
  import SMWeb.Components.ValidationCheckmark

  alias SM.Competitions
  alias SM.Slides
  alias SM.Subjects
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Submit

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:flagged_slides, [])
      |> assign(:subjects, Subjects.list())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("apply-subject-correction", %{"slide-id" => slide_id, "new-subject" => new_subject}, socket) do
    socket =
      case Slides.apply_correct_subject(slide_id, new_subject) do
        {:ok, _slide} ->
          socket
          |> put_flash(:info, gettext("Subject correction applied successfully"))
          |> push_navigate(to: "/organize/#{socket.assigns.competition.id}/validation_launcher")

        {:error, _reason} = error ->
          Logger.error("Unable to apply correct subject to slide #{slide_id}: #{inspect(error)}")
          put_flash(socket, :error, gettext("Error applying subject correction to slide"))
      end

    {:noreply, socket}
  end

  def handle_event("move-slide-to-jury", %{"slide-id" => slide_id}, socket) do
    socket =
      with {:ok, slide} <- Slides.get(slide_id),
           {:ok, _slide} <- Slides.update(slide, %{"status" => :submitted_jury}) do
        socket
        |> put_flash(:info, gettext("Slide moved to jury"))
        |> push_navigate(to: "/organize/#{socket.assigns.competition.id}/validation_launcher")
      else
        {:error, _reason} = error ->
          Logger.error("Unable to move slide #{slide_id} to jury: #{inspect(error)}")
          put_flash(socket, :error, gettext("Error moving slide to jury"))
      end

    {:noreply, socket}
  end

  def handle_event("move-slide-to-fixed", %{"slide-id" => slide_id}, socket) do
    socket =
      with {:ok, slide} <- Slides.get(slide_id),
           {:ok, _slide} <- Slides.update(slide, %{"status" => :submitted_fixed}) do
        socket
        |> put_flash(:info, gettext("Slide moved to fixed points"))
        |> push_navigate(to: "/organize/#{socket.assigns.competition.id}/validation_launcher")
      else
        {:error, _reason} = error ->
          Logger.error("Unable to move slide #{slide_id} to fixed points: #{inspect(error)}")
          put_flash(socket, :error, gettext("Error moving slide to fixed points"))
      end

    {:noreply, socket}
  end

  def handle_event("move-slide-to-discarded", %{"slide-id" => slide_id}, socket) do
    socket =
      with {:ok, slide} <- Slides.get(slide_id),
           {:ok, _slide} <- Slides.update(slide, %{"status" => :discarded}) do
        socket
        |> put_flash(:info, gettext("Slide moved to discarded"))
        |> push_navigate(to: "/organize/#{socket.assigns.competition.id}/validation_launcher")
      else
        {:error, _reason} = error ->
          Logger.error("Unable to move slide #{slide_id} to discarded: #{inspect(error)}")
          put_flash(socket, :error, gettext("Error moving slide to discarded"))
      end

    {:noreply, socket}
  end

  def handle_event("clear-all-flags", %{"slide-id" => slide_id}, socket) do
    {:ok, _deleted} = Slides.clear_slide_flags(slide_id)

    socket =
      socket
      |> put_flash(:info, gettext("Removed all slide flags"))
      |> push_navigate(to: "/organize/#{socket.assigns.competition.id}/validation_launcher")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    {:ok, competition} = Competitions.get(competition_id)

    stats =
      if competition.for_teams do
        get_teams_stats(competition)
      else
        get_participants_stats(competition)
      end

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:stats, stats)

    {:noreply, socket}
  end

  # Internal

  defp get_participants_stats(competition) do
    competition_id = competition.id

    flagged_slides = Slides.list_flagged(competition_id)
    duplicate_subjects = Slides.list_duplicate_subjects(competition_id)

    # TODO: make jolly coefficient value customizable in Competition settings
    jolly_coefficient = 2

    low_coeff_slides_cnt =
      competition_id
      |> Slides.count_jury_slides_by_static_coefficient(jolly_coefficient)
      |> Map.new()

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
          {^participant_number, slide} -> [slide]
          {_participant_number, _slide} -> []
        end)

      over_submitted_threshold = check_submitted_threshold(stats.submitted_fixed, stats.submitted_jury, competition)

      low_coeff_slides_cnt = Map.get(low_coeff_slides_cnt, participant_number, 0)

      over_jury_threshold =
        check_jury_threshold(stats.submitted_fixed, stats.submitted_jury, competition, low_coeff_slides_cnt)

      new_stats =
        Map.merge(stats, %{
          flagged_slides: flagged_slides,
          duplicate_subjects: duplicate_subjects,
          over_submitted_threshold: over_submitted_threshold,
          over_jury_threshold: over_jury_threshold
        })

      {participant_number, new_stats}
    end)
    |> List.keysort(0)
  end

  defp get_teams_stats(competition) do
    competition_id = competition.id

    flagged_slides = Slides.list_teams_flagged(competition_id)
    duplicate_subjects = Slides.list_teams_duplicate_subjects(competition_id)

    # TODO: make jolly coefficient value customizable in Competition settings
    jolly_coefficient = 2

    low_coeff_slides_cnt =
      competition_id
      |> Slides.count_teams_jury_slides_by_static_coefficient(jolly_coefficient)
      |> Map.new()

    competition_id
    |> Slides.list_stats_by_team()
    |> Enum.reduce(%{}, fn {team_number, p_stats}, acc ->
      new_stats =
        acc
        |> Map.get(team_number, %{})
        |> Map.merge(p_stats)
        |> Map.put_new(:submitted_jury, 0)
        |> Map.put_new(:submitted_fixed, 0)

      Map.put(acc, team_number, new_stats)
    end)
    |> Enum.map(fn {team_number, stats} ->
      flagged_slides =
        Enum.flat_map(flagged_slides, fn
          {^team_number, _participant_number, slide} -> [slide]
          {_team_number, _participant_number, _slide} -> []
        end)

      duplicate_subjects =
        Enum.flat_map(duplicate_subjects, fn
          {^team_number, _participant_number, slide} -> [slide]
          {_team_number, _participant_number, _slide} -> []
        end)

      over_submitted_threshold = check_submitted_threshold(stats.submitted_fixed, stats.submitted_jury, competition)

      low_coeff_slides_cnt = Map.get(low_coeff_slides_cnt, team_number, 0)

      over_jury_threshold =
        check_jury_threshold(stats.submitted_fixed, stats.submitted_jury, competition, low_coeff_slides_cnt)

      new_stats =
        Map.merge(stats, %{
          flagged_slides: flagged_slides,
          duplicate_subjects: duplicate_subjects,
          over_submitted_threshold: over_submitted_threshold,
          over_jury_threshold: over_jury_threshold
        })

      {team_number, new_stats}
    end)
    |> List.keysort(0)
  end

  defp subject_name(subjects, subject_id) do
    Enum.find_value(subjects, gettext("N/A"), fn s ->
      if s.id == subject_id, do: s.name
    end)
  end

  defp status_to_label(:submitted_fixed), do: gettext("Fixed points")
  defp status_to_label(:submitted_jury), do: gettext("Jury")

  defp list_to_boolean([]), do: false
  defp list_to_boolean([_ | _]), do: true

  defp list_to_variant([]), do: :pass
  defp list_to_variant([_ | _]), do: :fail

  defp submitted_threshold_tooltip({_result, submitted_slides_cnt, threshold}) do
    "#{submitted_slides_cnt}/#{threshold}"
  end

  defp jury_threshold_tooltip({_result, jury_slides_cnt, threshold, 0}) do
    "#{jury_slides_cnt}/#{threshold}"
  end

  defp jury_threshold_tooltip({_result, jury_slides_cnt, threshold, jolly_slides}) do
    "#{jury_slides_cnt}/#{threshold}+#{jolly_slides}"
  end

  defp check_submitted_threshold(fixed_slides_cnt, jury_slides_cnt, competition) do
    submitted_slides_cnt = fixed_slides_cnt + jury_slides_cnt
    submitted_threshold = competition.settings.max_submitted_slides

    result = if submitted_slides_cnt <= submitted_threshold, do: :pass, else: :fail

    {result, submitted_slides_cnt, submitted_threshold}
  end

  defp check_jury_threshold(fixed_slides_cnt, jury_slides_cnt, competition, low_coeff_slides_cnt) do
    submitted_slides_cnt = fixed_slides_cnt + jury_slides_cnt

    threshold =
      if competition.settings.proportional_submission do
        proportional_jury_threshold(submitted_slides_cnt, competition.settings.submission_ratio)
      else
        competition.settings.max_jury_slides
      end

    jolly? = jolly_slide?(competition, low_coeff_slides_cnt > 0)

    rounded_threshold = Decimal.round(threshold)

    # TODO: make number of jolly slides customizable in Competition settings
    jolly_slides = 1
    adj_threshold = if jolly?, do: Decimal.add(rounded_threshold, jolly_slides), else: rounded_threshold

    result = if Decimal.compare(jury_slides_cnt, adj_threshold) in [:lt, :eq], do: :pass, else: :fail
    {result, jury_slides_cnt, rounded_threshold, (jolly? && jolly_slides) || 0}
  end

  defp jolly_slide?(competition, has_lower_coeff_slide?) when is_boolean(has_lower_coeff_slide?) do
    not (competition.settings.dynamic_coefficient_mode != :disabled) and has_lower_coeff_slide?
  end

  defp proportional_jury_threshold(submitted_slides_cnt, jury_ratio) do
    # TODO: Make this limit configurable in Competition settings
    jury_threshold_min_limit = 12

    submitted_slides_cnt
    |> Decimal.mult(jury_ratio)
    |> Decimal.max(jury_threshold_min_limit)
  end
end
