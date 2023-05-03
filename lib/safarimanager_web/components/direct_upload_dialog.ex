defmodule SMWeb.Components.DirectUploadDialog do
  @moduledoc """
  Auto upload dialog component.
  """
  use SMWeb, :surface_live_component

  alias SM.FileBrowser
  alias SM.Participants.Participant
  alias SM.Slides
  alias SM.USBWatcherSupervisor
  alias SMWeb.Components.Dialog
  alias SMWeb.Components.DirectUploadDialog
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Select

  require Logger

  data show, :boolean, default: false
  data cwd, :string, default: "~/"
  data items, :list, default: []
  data user_id, :string, default: nil
  data progress, :decimal, default: Decimal.new(0)
  prop file_filter, :list, default: []

  # Public API

  @spec show(String.t(), String.t(), String.t(), [Participant.t()]) :: any()
  def show(dialog_id, new_volume, competition_id, participants) do
    pid =
      case USBWatcherSupervisor.get_poller_pid() do
        {:ok, pid} ->
          pid

        {:error, :no_active_pollers} ->
          nil
      end

    {:ok, cwd} = FileBrowser.cd(new_volume)

    send_update(__MODULE__,
      id: dialog_id,
      show: true,
      cwd: cwd,
      items: FileBrowser.ls!(cwd),
      watcher_pid: pid,
      competition_id: competition_id,
      participants: participants,
      user_id: nil,
      progress: Decimal.new(0)
    )
  end

  @spec hide(String.t()) :: any()
  def hide(dialog_id) do
    send_update(__MODULE__,
      id: dialog_id,
      show: false,
      items: [],
      watcher_pid: nil,
      competition_id: nil,
      participants: []
    )
  end

  # Event handlers

  @impl Phoenix.LiveComponent
  def handle_event("hide", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, show: false)}
  end

  def handle_event("hide", _value, socket) do
    {:noreply, assign(socket, show: false)}
  end

  def handle_event("level-down", %{"item" => item}, socket) do
    {:ok, cwd} = FileBrowser.cd(socket.assigns.cwd, item)
    dir_items = FileBrowser.ls!(cwd, filter: socket.assigns.file_filter)

    socket =
      socket
      |> assign(:cwd, cwd)
      |> assign(:items, dir_items)

    {:noreply, socket}
  end

  def handle_event("level-up", _params, socket) do
    {:ok, cwd} = FileBrowser.cd(socket.assigns.cwd, "..")
    dir_items = FileBrowser.ls!(cwd, filter: socket.assigns.file_filter)

    socket =
      socket
      |> assign(:cwd, cwd)
      |> assign(:items, dir_items)

    {:noreply, socket}
  end

  def handle_event("import", _params, socket) do
    pid = self()
    assigns = socket.assigns

    to_be_imported = Path.wildcard("#{assigns.cwd}/*.{jpg,JPG,jpeg,JPEG}")
    to_be_imported_cnt = Enum.count(to_be_imported)

    _result =
      Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
        import_result =
          Enum.reduce(to_be_imported, 0, fn source_path, acc ->
            file_name = Path.basename(source_path)
            %File.Stat{size: file_size} = File.stat!(source_path)

            {:ok, _slide} =
              Slides.create_and_store_slide_file(
                assigns.competition_id,
                assigns.user_id,
                file_name,
                file_size,
                "image/jpeg",
                source_path
              )

            :ok =
              Slides.generate_thumbnail(
                assigns.competition_id,
                assigns.user_id,
                file_name,
                :small
              )

            progress = Decimal.div(acc + 1, to_be_imported_cnt)

            send_update(pid, DirectUploadDialog,
              id: "auto-upload-dialog",
              progress: progress
            )

            # If importing is complete, close the dialog after 1 second
            :ok = maybe_close_dialog(progress, pid)

            acc + 1
          end)

        Logger.info(
          "Imported #{import_result}/#{to_be_imported_cnt} Slides for User #{assigns.user_id} in Competition #{assigns.competition_id}"
        )
      end)

    {:noreply, socket}
  end

  def handle_event("validate", %{"slide_import" => %{"user_id" => ""}}, socket) do
    socket = assign(socket, :user_id, nil)
    {:noreply, socket}
  end

  def handle_event("validate", %{"slide_import" => %{"user_id" => user_id}}, socket) do
    socket = assign(socket, :user_id, user_id)
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  # Internal

  defp maybe_close_dialog(progress, pid) do
    _ref =
      if Decimal.equal?(progress, 1) do
        send_update_after(
          pid,
          DirectUploadDialog,
          [id: "auto-upload-dialog", show: false],
          1000
        )
      end

    :ok
  end

  defp count_image_type(items) do
    Enum.count(items, &(&1.type == :img))
  end

  defp participant_select_option_txt(participant) do
    Enum.join(
      [
        participant.number,
        "#{participant.user.first_name} #{participant.user.last_name}",
        (participant.user.organization && participant.user.organization.name) || "N/A",
        (participant.category && participant.category.name) || "N/A"
      ],
      " - "
    )
  end

  defp can_import?(user_id, items) do
    not is_nil(user_id) and count_image_type(items) > 0
  end
end
