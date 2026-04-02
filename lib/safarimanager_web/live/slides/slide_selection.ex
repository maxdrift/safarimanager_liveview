defmodule SMWeb.Live.SlideSelection do
  @moduledoc """
  Slide selection view
  """
  use SMWeb, :live_view

  import SMWeb.Components.CompetitionHeader
  import SMWeb.Components.Layout
  import SMWeb.Components.SlidesSelectionList
  import SMWeb.Components.StepsHeader
  import SMWeb.Components.UploadDropArea

  alias Phoenix.LiveView
  alias SM.Accounts
  alias SM.Competitions
  alias SM.Participants
  alias SM.Slides
  alias SM.Slides.SelectionImport
  alias SM.Subjects
  alias SM.Teams

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        user: nil,
        team: nil,
        participants: [],
        teams: [],
        slides: [],
        slide_statuses: get_slide_statuses(),
        editing?: false,
        editing_slide: nil,
        editing_form: nil,
        subjects: []
      )
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        progress: &handle_progress/3,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("filter-participants", %{"value" => ""}, socket) do
    participants = Participants.list(socket.assigns.competition_id)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("filter-participants", %{"value" => value}, socket) do
    participants = Participants.filter_by_name(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("start-editing", %{"id" => slide_id}, socket) do
    {:ok, slide} = Slides.get(slide_id)

    socket =
      socket
      |> assign(:editing?, true)
      |> assign(:editing_slide, slide)
      |> assign(:editing_form, to_form(Slides.change(slide)))

    {:noreply, socket}
  end

  def handle_event("validate-editing", %{"slide" => params}, socket) do
    if socket.assigns.editing_slide do
      form =
        socket.assigns.editing_slide
        |> Slides.change(params)
        |> to_form(action: :validate)

      socket = assign(socket, :editing_form, form)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("submit-editing", %{"slide" => params}, socket) do
    socket =
      case Slides.update(socket.assigns.editing_slide, params) do
        {:ok, _entity} ->
          socket
          |> assign(:editing?, false)
          |> assign(:editing_slide, nil)
          |> assign(:editing_form, nil)

        {:error, changeset} ->
          assign(socket, :editing_form, to_form(changeset))
      end

    {:noreply, socket}
  end

  def handle_event("stop-editing", %{}, socket) do
    socket =
      socket
      |> assign(:editing?, false)
      |> assign(:editing_slide, nil)
      |> assign(:editing_form, nil)

    {:noreply, socket}
  end

  def handle_event(event_name, params, socket) do
    Logger.debug("#{inspect({event_name, params})}")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    _result =
      if connected?(socket),
        do: {Competitions.subscribe(), Accounts.subscribe(), Slides.subscribe()}

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :load_user, %{"competition_id" => competition_id, "user_id" => user_id}) do
    {:ok, competition} = Competitions.get(competition_id)

    grouped_slides = get_user_slides_by_status(user_id, competition_id)

    assign(socket,
      competition_id: competition_id,
      competition: competition,
      participants: Participants.list(competition_id),
      teams: Teams.list_by_competition(competition_id),
      user: Accounts.get_user!(user_id),
      team: nil,
      discarded_slides: Map.get(grouped_slides, :discarded, []),
      jury_slides: Map.get(grouped_slides, :submitted_jury, []),
      fixed_slides: Map.get(grouped_slides, :submitted_fixed, []),
      subjects: Competitions.list_subjects_for_competition(competition_id)
    )
  end

  defp apply_action(socket, :load_team, %{"competition_id" => competition_id, "team_id" => team_id}) do
    {:ok, competition} = Competitions.get(competition_id)

    grouped_slides = get_team_slides_by_status(team_id, competition_id)

    {:ok, team} = Teams.get(team_id)

    assign(socket,
      competition_id: competition_id,
      competition: competition,
      participants: Participants.list(competition_id),
      teams: Teams.list_by_competition(competition_id),
      user: nil,
      team: team,
      discarded_slides: Map.get(grouped_slides, :discarded, []),
      jury_slides: Map.get(grouped_slides, :submitted_jury, []),
      fixed_slides: Map.get(grouped_slides, :submitted_fixed, []),
      subjects: Competitions.list_subjects_for_competition(competition_id)
    )
  end

  defp apply_action(socket, :index, %{"competition_id" => competition_id}) do
    {:ok, competition} = Competitions.get(competition_id)

    assign(socket,
      competition_id: competition_id,
      competition: competition,
      participants: Participants.list(competition_id),
      teams: Teams.list_by_competition(competition_id),
      user: nil,
      discarded_slides: [],
      jury_slides: [],
      fixed_slides: [],
      subjects: Competitions.list_subjects_for_competition(competition_id)
    )
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _], _result}, socket) do
    user = socket.assigns.user
    team = socket.assigns.team
    competition_id = socket.assigns.competition_id

    grouped_slides =
      cond do
        not is_nil(user) ->
          get_user_slides_by_status(user.id, competition_id)

        not is_nil(team) ->
          get_team_slides_by_status(team.id, competition_id)

        true ->
          %{}
      end

    socket =
      socket
      |> assign(:discarded_slides, Map.get(grouped_slides, :discarded, []))
      |> assign(:jury_slides, Map.get(grouped_slides, :submitted_jury, []))
      |> assign(:fixed_slides, Map.get(grouped_slides, :submitted_fixed, []))

    {:noreply, socket}
  end

  def handle_info({_context, [:competition, :updated], _result}, socket) do
    {:ok, competition} = Competitions.get(socket.assigns.competition_id)
    participants = Participants.list(socket.assigns.competition_id)
    teams = Teams.list_by_competition(socket.assigns.competition_id)

    socket =
      assign(socket, competition: competition, participants: participants, teams: teams)

    {:noreply, socket}
  end

  # Internal

  defp get_user_slides_by_status(nil, _competition_id), do: %{}

  defp get_user_slides_by_status(user_id, competition_id) do
    user_id
    |> Slides.list(competition_id)
    |> Enum.group_by(& &1.status)
  end

  defp get_team_slides_by_status(nil, _competition_id), do: %{}

  defp get_team_slides_by_status(team_id, competition_id) do
    team_id
    |> Slides.list_by_team(competition_id)
    |> Enum.group_by(& &1.status)
  end

  defp handle_progress(:csv, entry, socket) do
    with true <- entry.done?,
         :updated <- process_uploaded_csv(socket, entry) do
      socket = put_flash(socket, :info, gettext("Slide selection has been imported."))
      {:noreply, socket}
    else
      false ->
        {:noreply, socket}

      {:error, {:slide_not_found, file_name}} ->
        socket =
          put_flash(socket, :error, gettext("Unable to import slide selection: slide not found") <> " '#{file_name}'")

        {:noreply, socket}

      {:error, {:multiple_slides_found, file_name}} ->
        socket =
          put_flash(
            socket,
            :error,
            "#{gettext("Unable to import slide selection: multiple slides with the same file name (or very similar) were found")}: #{file_name}"
          )

        {:noreply, socket}

      {:error, :subject_not_found} ->
        socket =
          put_flash(
            socket,
            :error,
            gettext("Unable to import slide selection: subject not found")
          )

        {:noreply, socket}

      {:error, :parse_error} ->
        socket =
          put_flash(socket, :error, gettext("Unable to import slide selection: invalid CSV file"))

        {:noreply, socket}
    end
  end

  defp process_uploaded_csv(socket, %Phoenix.LiveView.UploadEntry{} = entry) do
    # lv = self()
    competition_id = socket.assigns.competition_id
    users = (socket.assigns.user && [socket.assigns.user]) || socket.assigns.team.users

    LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
      path
      |> SelectionImport.parse()
      |> Stream.map(fn row ->
        with {:ok, subject} <- find_subject(row.subject_num),
             {:ok, slide} <- find_slide(competition_id, users, row.file_name),
             {:ok, _slide} <-
               Slides.update(slide, %{
                 subject_id: subject.id,
                 status: Slides.jury_bool_to_status(row.jury?)
               }),
             do: :ok
      end)
      |> Stream.filter(fn
        {:error, _reason} -> true
        :ok -> false
      end)
      |> Enum.to_list()
      |> case do
        [] ->
          {:ok, :updated}

        [first_error | _rest] ->
          # Wrapping the error in a ok-tuple because LiveView.consume_uploaded_entry/3
          # expects a result of {:ok, any()} or {:postpone, any()} and we don't need
          # to postpone in this case.
          {:ok, first_error}
      end
    end)
  rescue
    e in NimbleCSV.ParseError ->
      Logger.error("Unable to parse CSV: #{inspect(e)}")
      {:error, :parse_error}
  end

  defp find_subject(subject_num) do
    case Subjects.get_by_numeric_id(subject_num) do
      {:ok, subject} -> {:ok, subject}
      {:error, :not_found} -> {:error, :subject_not_found}
    end
  end

  defp find_slide(_competition_id, [], file_name) do
    {:error, {:slide_not_found, file_name}}
  end

  defp find_slide(competition_id, [user | rest], file_name) do
    case Slides.get(competition_id, user.id, file_name) do
      {:ok, slide} ->
        {:ok, slide}

      {:error, :not_found} ->
        find_slide(competition_id, rest, file_name)

      {:error, {:multiple_results, file_name}} ->
        {:error, {:multiple_slides_found, file_name}}
    end
  end

  defp get_slide_statuses do
    Slides.list_slide_statuses()
  end

  defp get_status_select_options do
    Enum.map(Slides.list_slide_statuses(), &{status_to_label(&1), &1})
  end

  defp status_to_label(:submitted_fixed), do: gettext("Fixed points")
  defp status_to_label(:submitted_jury), do: gettext("Jury")
  # Gettext hack to reuse existing localization
  defp status_to_label(:discarded), do: ngettext("Discarded", "Discarded", 1)
end
