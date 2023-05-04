defmodule SMWeb.SlideSelection do
  @moduledoc """
  Slide selection view
  """
  use SMWeb, :surface_view

  alias Phoenix.LiveView
  alias SM.Accounts
  alias SM.Competitions
  alias SM.Participants
  alias SM.Slides
  alias SM.Slides.SelectionImport
  alias SM.Subjects
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.Layout
  alias SMWeb.Components.StepsHeader
  alias SMWeb.Components.UploadDropArea
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput
  alias Surface.Components.LivePatch
  alias Surface.Components.LiveRedirect

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:user, nil)
      |> assign(:participants, [])
      |> assign(:slides, [])
      |> assign(:slide_statuses, get_slide_statuses())
      |> assign(:editing?, false)
      |> assign(:editing_slide, nil)
      |> assign(:editing_changeset, nil)
      |> assign(:subjects, Subjects.list())
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
    participants = Participants.list(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("start-editing", %{"id" => slide_id}, socket) do
    {:ok, slide} = Slides.get(slide_id)

    socket =
      socket
      |> assign(:editing?, true)
      |> assign(:editing_slide, slide)
      |> assign(:editing_changeset, Slides.change(slide))

    {:noreply, socket}
  end

  def handle_event("validate-editing", %{"slide" => params}, socket) do
    changeset =
      socket.assigns.editing_slide
      |> Slides.change(params)
      |> Map.put(:action, :validate)

    socket = assign(socket, :editing_changeset, changeset)
    {:noreply, socket}
  end

  def handle_event("submit-editing", %{"slide" => params}, socket) do
    socket =
      case Slides.update(socket.assigns.editing_slide, params) do
        {:ok, _entity} ->
          socket
          |> assign(:editing?, false)
          |> assign(:editing_slide, nil)
          |> assign(:editing_changeset, nil)

        {:error, changeset} ->
          assign(socket, :editing_changeset, changeset)
      end

    {:noreply, socket}
  end

  def handle_event("stop-editing", %{}, socket) do
    socket =
      socket
      |> assign(:editing?, false)
      |> assign(:editing_slide, nil)
      |> assign(:editing_changeset, nil)

    {:noreply, socket}
  end

  def handle_event(event_name, params, socket) do
    Logger.debug("#{inspect({event_name, params})}")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id} = params, _uri, socket) do
    _result =
      if connected?(socket),
        do: {Competitions.subscribe(), Accounts.subscribe(), Slides.subscribe()}

    user_id = params["user_id"]

    {:ok, competition} = Competitions.get(competition_id)

    grouped_slides = get_slides_by_status(user_id, competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:participants, Participants.list(competition_id))
      # FIXME: this way of selecting the user forces a re-query of Competition
      |> assign(:user, user_id && Accounts.get_user!(user_id))
      |> assign(:discarded_slides, user_id && Map.get(grouped_slides, :discarded, []))
      |> assign(:jury_slides, user_id && Map.get(grouped_slides, :submitted_jury, []))
      |> assign(:fixed_slides, user_id && Map.get(grouped_slides, :submitted_fixed, []))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _], _result}, socket) do
    user_id = socket.assigns.user.id
    competition_id = socket.assigns.competition_id

    grouped_slides = get_slides_by_status(user_id, competition_id)

    socket =
      socket
      |> assign(:discarded_slides, user_id && Map.get(grouped_slides, :discarded, []))
      |> assign(:jury_slides, user_id && Map.get(grouped_slides, :submitted_jury, []))
      |> assign(:fixed_slides, user_id && Map.get(grouped_slides, :submitted_fixed, []))

    {:noreply, socket}
  end

  def handle_info({_context, [:competition, :updated], _result}, socket) do
    {:ok, competition} = Competitions.get(socket.assigns.competition_id)
    participants = Participants.list(socket.assigns.competition_id)

    socket =
      socket
      |> assign(:competition, competition)
      |> assign(:participants, participants)

    {:noreply, socket}
  end

  # Internal

  defp get_slides_by_status(nil, _competition_id), do: %{}

  defp get_slides_by_status(user_id, competition_id) do
    user_id
    |> Slides.list(competition_id)
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

      {:error, :slide_not_found} ->
        socket =
          put_flash(socket, :error, gettext("Unable to import slide selection: slide not found"))

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
    user_id = socket.assigns.user.id

    LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
      path
      |> SelectionImport.parse()
      |> Stream.map(fn row ->
        with {:ok, subject} <- find_subject(row.subject_num),
             {:ok, slide} <- find_slide(competition_id, user_id, row.file_name),
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

  defp find_slide(competition_id, user_id, file_name) do
    case Slides.get(competition_id, user_id, file_name) do
      {:ok, slide} -> {:ok, slide}
      {:error, :not_found} -> {:error, :slide_not_found}
    end
  end

  defp get_slide_statuses do
    Slides.list_slide_statuses()
  end

  defp pretty_size(byte_size) do
    cond do
      byte_size >= 1_000_000_000 ->
        byte_size
        |> Decimal.new()
        |> Decimal.div(1_000_000_000)
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("GB")

      byte_size >= 1_000_000 ->
        byte_size
        |> Decimal.new()
        |> Decimal.div(1_000_000)
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("MB")

      byte_size >= 1000 ->
        byte_size
        |> Decimal.new()
        |> Decimal.div(1000)
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("KB")

      true ->
        byte_size
        |> Decimal.new()
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("B")
    end
  end

  defp thumbnail_path(slide) do
    ~p"/uploads/#{slide.competition_id}/#{slide.user_id}/thumbnails/small/#{slide.file_name}"
  end
end
