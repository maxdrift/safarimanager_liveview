defmodule SMWeb.Live.Slides do
  @moduledoc """
  Slides live view
  """
  use SMWeb, :surface_view

  alias Phoenix.LiveView
  alias SM.Accounts
  alias SM.Competitions
  alias SM.Participants
  alias SM.Slides
  alias SM.Teams
  alias SM.USBWatcherSupervisor
  alias SM.Utils
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.DirectUploadDialog
  alias SMWeb.Components.FileBrowser
  alias SMWeb.Components.Layout
  alias SMWeb.Components.StepsHeader
  alias SMWeb.Components.UploadDropArea
  alias Surface.Components.Form
  alias Surface.Components.Form.Checkbox
  alias Surface.Components.Form.TextInput

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        user: nil,
        participants: [],
        teams: [],
        slides: [],
        direct_file_upload: Slides.direct_file_upload?(),
        discovery_mode: USBWatcherSupervisor.active?()
      )
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
  def handle_event("validate", %{"_target" => ["discovery_mode"], "discovery_mode" => values}, socket) do
    if "true" in values do
      :ok = USBWatcherSupervisor.start_poller(self())
    else
      :ok = USBWatcherSupervisor.stop_poller()
    end

    {:noreply, socket}
  end

  def handle_event("validate", %{"_target" => ["images"]}, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.images.entries, socket, fn entry, socket_acc ->
        assigns = socket_acc.assigns

        case Slides.get(assigns.competition_id, assigns.user.id, entry.client_name) do
          {:ok, result} ->
            Logger.info("Cancelling upload of #{entry.client_name}: duplicate of Slide #{result.id}")

            LiveView.cancel_upload(socket_acc, :images, entry.ref)

          {:error, :not_found} ->
            socket_acc
        end
      end)

    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("delete-slide", %{"id" => slide_id}, socket) do
    on_confirm = fn socket ->
      with {:ok, slide} <- Slides.get(slide_id),
           do: Slides.delete(slide)

      #  TODO: use handle_info to update the list
      participants = Participants.list(socket.assigns.competition_id)
      assign(socket, participants: participants)
    end

    {:noreply,
     confirm(socket, on_confirm,
       title: gettext("Delete slide"),
       description: gettext("Are you sure you want to delete this slide?"),
       confirm_text: gettext("Delete"),
       confirm_icon: "trash"
     )}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, LiveView.cancel_upload(socket, :images, ref)}
  end

  def handle_event("delete-all-slides", %{}, socket) do
    on_confirm = fn socket ->
      [_head | _tail] =
        for slide <- socket.assigns.slides do
          {:ok, _slide} = Slides.delete(slide)
        end

      #  TODO: use handle_info to update the list
      participants = Participants.list(socket.assigns.competition_id)
      assign(socket, participants: participants)
    end

    {:noreply,
     confirm(socket, on_confirm,
       title: gettext("Delete all slides"),
       description: gettext("Are you sure you want to delete all slides?"),
       confirm_text: gettext("Delete"),
       confirm_icon: "trash"
     )}
  end

  def handle_event("filter-participants", %{"value" => ""}, socket) do
    participants = Participants.list(socket.assigns.competition_id)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("filter-participants", %{"value" => value}, socket) do
    participants = Participants.filter_by_name(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("show-upload-dialog", _params, socket) do
    DirectUploadDialog.show(
      "auto-upload-dialog",
      "~/",
      socket.assigns.competition_id,
      socket.assigns.participants
    )

    {:noreply, socket}
  end

  def handle_event("direct-import", %{"cwd" => cwd, "items" => items}, socket) do
    pid = self()
    competition_id = socket.assigns.competition_id
    user_id = socket.assigns.user && socket.assigns.user.id

    to_be_imported =
      items
      |> String.split(",")
      |> Enum.map(&Path.join(cwd, &1))

    to_be_imported_cnt = Enum.count(to_be_imported)

    _result =
      Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
        import_result =
          Enum.reduce(to_be_imported, 0, fn source_path, acc ->
            file_name = Path.basename(source_path)
            %File.Stat{size: file_size} = File.stat!(source_path)

            {:ok, _slide} =
              Slides.create_and_store_slide_file(
                competition_id,
                user_id,
                file_name,
                file_size,
                "image/jpeg",
                source_path
              )

            :ok =
              Slides.generate_thumbnail(
                competition_id,
                user_id,
                file_name,
                :small
              )

            progress = Decimal.div(acc + 1, to_be_imported_cnt)
            send_update(pid, FileBrowser, id: "file-browser", upload_progress: progress)

            acc + 1
          end)

        :ok = Process.send(pid, {:refresh, :participants}, [])

        Logger.info(
          "Imported #{import_result}/#{to_be_imported_cnt} Slides for User #{user_id} in Competition #{competition_id}"
        )
      end)

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
    participants = Participants.list(competition_id)
    teams = Teams.list_by_competition(competition_id)

    socket =
      assign(
        socket,
        competition_id: competition_id,
        competition: competition,
        participants: participants,
        teams: teams,
        # FIXME: this way of selecting the user forces a re-query of Competition
        user: user_id && Accounts.get_user!(user_id),
        slides: user_id && Slides.list(user_id, competition_id)
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _], _result}, socket) do
    user_id = (socket.assigns.user && socket.assigns.user.id) || nil
    competition_id = socket.assigns.competition_id

    socket = assign(socket, slides: user_id && Slides.list(user_id, competition_id))

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

  def handle_info({:refresh, :participants}, socket) do
    participants = Participants.list(socket.assigns.competition_id)
    teams = Teams.list_by_competition(socket.assigns.competition_id)

    socket = assign(socket, participants: participants, teams: teams)

    {:noreply, socket}
  end

  def handle_info({:new_volumes, new_volumes}, socket) do
    Logger.debug("new volume mounted from Component!!")
    [first_volume | _tail] = new_volumes
    competition_id = socket.assigns.competition_id
    participants = socket.assigns.participants
    DirectUploadDialog.show("auto-upload-dialog", first_volume, competition_id, participants)

    {:noreply, socket}
  end

  def handle_info(:volumes_removed, socket) do
    Logger.debug("volume removed from Component!!")
    DirectUploadDialog.hide("auto-upload-dialog")

    {:noreply, socket}
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  # defp get_entry!(socket, file_name) do
  #   Enum.find(socket.assigns.uploads.images.entries, fn entry ->
  #     entry.client_name == file_name
  #   end) ||
  #     raise "no entry found for ref #{inspect(file_name)}"
  # end

  defp handle_progress(:images, entry, socket) do
    # SongEntryComponent.send_progress(entry)

    if entry.done? do
      Logger.info("File with ref.#{entry.ref} successfully uploaded")
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
      :ok =
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
            Logger.error("Failed to create Slide and/or store file #{file_name}: #{inspect(reason)}")

            error
        end

      uploads_path = Path.join(uploads_path, file_name)
      {:ok, :thumbnail_generated} = generate_thumbnails(competition_id, user_id, file_name)

      # TODO: verify correctness according to verified routes
      {:ok, uploads_path}
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
        Logger.error("Unable to generate #{size_type} thumbnail for image #{file_name}: #{inspect(reason)}")

        error
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
end
