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

  def render(assigns) do
    ~F"""
    <Dialog {=@id} {=@show}>
      <div class="text-xl font-bold text-center">
        {gettext("Image import")}
      </div>
      <div class="my-2">
        <progress
          class={"progress", "progress-secondary", invisible: Decimal.equal?(@progress, 0)}
          value={Decimal.mult(@progress, 100) |> Decimal.round()}
          max="100"
        />
      </div>
      <div class="mb-4">
        <Form for={%{}} as={:slide_import} change="validate">
          <Field name={:user_id} class="form-control">
            <Select
              options={Enum.map(@participants, &{participant_select_option_txt(&1), &1.user_id})}
              prompt={[key: gettext("Select a participant...")]}
              selected={@user_id}
              class="input input-bordered"
            />
            <Label class="label h-7">
              <ErrorTag />
            </Label>
          </Field>
        </Form>
      </div>
      <div class="my-6">
        <div>
          <button :on-click="level-up" class="btn btn-outline btn-xs gap-1">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M7 11l5-5m0 0l5 5m-5-5v12" />
            </svg>
            {gettext("Level up")}
          </button>
        </div>
        <div class="flex flex-col mt-4 max-h-60 overflow-y-auto tiny-scrollbar">
          {#for %{type: type, name: item} <- @items}
            <div>
              <button
                :if={type == :dir}
                :on-click="level-down"
                :values={item: item}
                class="btn btn-ghost btn-xs gap-1"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
                  />
                </svg>
                {Path.basename(item)}
              </button>
              <button :if={type == :img} class="btn btn-link btn-xs btn-disabled gap-1">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
                {Path.basename(item)}
              </button>
            </div>
          {/for}
        </div>
      </div>
      <div class="flex flex-row w-full">
        <button
          class={"flex-none", "btn", "btn-primary", "btn-disabled": not can_import?(@user_id, @items)}
          :on-click="import"
        >
          {gettext("Import")}<span :if={can_import?(@user_id, @items)}>&nbsp;{count_image_type(@items)} {gettext("images")}</span>
        </button>
        <div class="grow" />
        <button class="flex-none btn btn-error" :on-click="hide">{gettext("Close")}</button>
      </div>
    </Dialog>
    """
  end

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
