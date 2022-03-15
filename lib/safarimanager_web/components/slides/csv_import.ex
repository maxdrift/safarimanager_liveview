defmodule SMWeb.CSVImport do
  @moduledoc """
  Slides CSV import view
  """
  use SMWeb, :surface_view

  alias Phoenix.LiveView
  alias SM.Accounts
  alias SM.Competitions
  alias SM.CSVImport
  alias SM.Slides
  alias SM.Subjects
  alias Surface.Components.LiveFileInput
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit
  alias Surface.Components.LiveRedirect
  alias Surface.Components.LivePatch

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:user, nil)
      |> assign(:slides, [])
      |> assign(:slide, nil)
      |> assign(:edit_mode, false)
      |> assign(:slide_id, nil)
      |> assign(:slide_statuses, get_slide_statuses())
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("submit", %{}, socket) do
    LiveView.consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
      csv_results = CSVImport.parse(path)
      # TODO: Stream here
      results =
        Enum.map(csv_results, fn %{
                                   file_name: file_name,
                                   jury?: jury?,
                                   subject_num: subject_num
                                 } ->
          jury? = if String.downcase(jury?) == "x", do: :submitted_jury, else: :submitted_fixed

          with {:ok, subject} <- Subjects.get_by_numeric_id(subject_num),
               {:ok, slide} <-
                 Slides.get(
                   socket.assigns.competition_id,
                   socket.assigns.user.id,
                   file_name <> ".JPG"
                 ),
               {:ok, slide} <- Slides.update(slide, %{subject_id: subject.id, status: jury?}),
               do: slide
        end)

      {:ok, results}
    end)
    |> List.flatten()
    # |> IO.inspect()
    |> Enum.filter(fn
      %Slides.Slide{} -> false
      {:error, _reason} -> true
    end)
    |> IO.inspect()

    {:noreply, socket}
  end

  def handle_event("edit-mode", %{"id" => slide_id}, socket) do
    {:ok, slide} = Slides.get(slide_id)

    socket =
      socket
      |> assign(:edit_mode, true)
      |> assign(:slide_id, slide_id)
      |> assign(:slide, slide)

    {:noreply, socket}
  end

  def handle_event("save-edits", %{} = params, socket) do
    IO.inspect(params)
    # {:ok, slide} = Slides.get(slide_id)
    # {:ok, _slide} =Slides.update(slide, )

    # socket =
    #   socket
    #   |> assign(:edit_mode, false)
    #   |> assign(:slide_id, nil)

    {:noreply, socket}
  end

  def handle_event("clear-edit-mode", %{}, socket) do
    socket =
      socket
      |> assign(:edit_mode, false)
      |> assign(:slide_id, nil)

    {:noreply, socket}
  end

  def handle_event(event_name, params, socket) do
    IO.inspect(event_name)
    IO.inspect(params)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView

  def handle_params(%{"competition_id" => competition_id} = params, _uri, socket) do
    user_id = params["user_id"]

    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      # FIXME: this way of selecting the user forces a re-query of Competition
      |> assign(:user, user_id && Accounts.get_user!(user_id))
      |> assign(:slides, user_id && Slides.list(user_id, competition_id))

    {:noreply, socket}
  end

  # Internal

  defp get_slide_statuses do
    Slides.list_slide_statuses()
  end

  defp image_path(socket, competition_id, user_id, file_name) do
    uploads_path = Slides.get_uploads_path(competition_id, user_id)

    socket
    |> Routes.static_path(uploads_path)
    |> Path.join(file_name)
  end
end
