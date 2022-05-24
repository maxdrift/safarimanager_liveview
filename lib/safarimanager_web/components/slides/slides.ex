defmodule SMWeb.Slides do
  @moduledoc """
  Slides live view
  """
  use SMWeb, :surface_view

  alias Phoenix.LiveView
  alias SM.Accounts
  alias SM.Competitions
  alias SM.Participants
  alias SM.Slides
  alias SM.USBWatcherSupervisor
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Form
  alias Surface.Components.Form.Checkbox
  alias Surface.Components.Form.FieldContext
  alias Surface.Components.Form.TextInput
  alias Surface.Components.LiveFileInput
  alias Surface.Components.LivePatch
  alias Surface.Components.LiveRedirect

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:user, nil)
      |> assign(:participants, [])
      |> assign(:slides, [])
      |> assign(:discovery_mode, USBWatcherSupervisor.active?())
      |> allow_upload(:images,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 500,
        max_file_size: 100_000_000,
        progress: &handle_progress/3,
        auto_upload: true,
        chunk_size: 1_024_000,
        chunk_timeout: 3_600_000
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "validate",
        %{"_target" => ["discovery_mode"], "discovery_mode" => values},
        socket
      ) do
    if "true" in values do
      :ok = USBWatcherSupervisor.start_poller()
    else
      :ok = USBWatcherSupervisor.stop_poller()
    end

    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("delete-slide", %{"id" => slide_id}, socket) do
    with {:ok, slide} <- Slides.get(slide_id),
         do: Slides.delete(slide)

    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, LiveView.cancel_upload(socket, :images, ref)}
  end

  def handle_event("delete-all-slides", %{}, socket) do
    for slide <- socket.assigns.slides do
      {:ok, _slide} = Slides.delete(slide)
    end

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

  def handle_event(event_name, params, socket) do
    IO.inspect(event_name, label: __MODULE__)
    IO.inspect(params)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id} = params, _uri, socket) do
    if connected?(socket),
      do: {Competitions.subscribe(), Accounts.subscribe(), Slides.subscribe()}

    user_id = params["user_id"]

    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:participants, Participants.list(competition_id))
      # FIXME: this way of selecting the user forces a re-query of Competition
      |> assign(:user, user_id && Accounts.get_user!(user_id))
      |> assign(:slides, user_id && Slides.list(user_id, competition_id))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _], _result}, socket) do
    user_id = socket.assigns.user.id
    competition_id = socket.assigns.competition_id

    socket = assign(socket, :slides, user_id && Slides.list(user_id, competition_id))

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

  # defp get_entry!(socket, file_name) do
  #   Enum.find(socket.assigns.uploads.images.entries, fn entry ->
  #     entry.client_name == file_name
  #   end) ||
  #     raise "no entry found for ref #{inspect(file_name)}"
  # end

  defp handle_progress(:images, entry, socket) do
    # IO.inspect(entry, label: __MODULE__)
    # SongEntryComponent.send_progress(entry)

    if entry.done? do
      IO.inspect("#{entry.ref} complete!", label: __MODULE__)
      process_uploaded_image(socket, entry)
      # async_calculate_duration(socket, entry)
    end

    # {:noreply, put_new_changeset(socket, entry)}
    {:noreply, socket}
  end

  defp process_uploaded_image(socket, %Phoenix.LiveView.UploadEntry{} = entry) do
    # lv = self()
    competition_id = socket.assigns.competition_id
    user_id = socket.assigns.user.id
    file_name = entry.client_name
    uploads_path = Slides.get_uploads_path(competition_id, user_id)

    LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
      case Slides.create_and_store_slide_file(
             competition_id,
             user_id,
             file_name,
             entry.client_size,
             entry.client_type,
             path
           ) do
        {:ok, _slide} ->
          :ok

        {:error, reason} = error ->
          Logger.error(
            "Failed to create Slide and/or store file #{file_name}: #{inspect(reason)}"
          )

          error
      end

      uploads_path = Path.join(uploads_path, file_name)
      {:ok, :thumbnail_generated} = generate_thumbnails(competition_id, user_id, file_name)

      {:ok, Routes.static_path(socket, uploads_path)}
      # Task.Supervisor.start_child(LiveBeats.TaskSupervisor, fn ->
      #   send_update(lv, __MODULE__,
      #     id: socket.assigns.id,
      #     action: {:duration, entry.ref, LiveBeats.MP3Stat.parse(path)}
      #   )
      # end)
    end)
  end

  defp generate_thumbnails(competition_id, user_id, file_name) do
    with {:ok, _pid} <-
           Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
             generate_thumbnail(competition_id, user_id, file_name, :small)
           end),
         #  {:ok, _pid} <-
         #    Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
         #      generate_thumbnail(competition_id, user_id, file_name, :medium)
         #    end),
         #  {:ok, _pid} <-
         #    Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
         #      generate_thumbnail(competition_id, user_id, file_name, :large)
         #    end),
         do: {:ok, :thumbnail_generated}
  end

  defp generate_thumbnail(competition_id, user_id, file_name, size_type) do
    case Slides.generate_thumbnail(competition_id, user_id, file_name, size_type) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.error(
          "Unable to generate #{size_type} thumbnail for image #{file_name}: #{inspect(reason)}"
        )

        error
    end
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

  defp sorted_images(entries, slides) do
    Enum.sort(entries ++ slides, fn left, right ->
      get_file_name(left) <= get_file_name(right)
    end)
  end

  defp get_file_name(item) do
    if is_slide?(item) do
      item.file_name
    else
      item.client_name
    end
  end

  defp is_slide?(item) do
    Map.has_key?(item, :id)
  end

  defp thumbnail_path(socket, slide) do
    path =
      Path.join([
        "/uploads",
        slide.competition_id,
        slide.user_id,
        "/thumbnails/small",
        slide.file_name
      ])

    Routes.static_path(socket, path)
  end
end
