defmodule SMWeb.Components.CompetitionDirectoryPanel do
  @moduledoc false
  use SMWeb, :live_component

  alias SM.CompetitionDirectories
  alias SM.FileBrowser

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <section
      id="competition-directory-panel"
      class="card bg-base-200 shadow-lg border border-base-300/60"
      aria-labelledby="competition-directory-title"
    >
      <div class="card-body gap-4">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 id="competition-directory-title" class="card-title text-lg">
            <Heroicons.icon name="folder-open" type="outline" class="w-5 h-5" />
            {gettext("Competition directory")}
          </h2>
          <span
            :if={@directory}
            id="competition-directory-status"
            class={["badge badge-sm gap-1", status_badge_class(@originals_status)]}
          >
            {reachability_label(@originals_status)}
          </span>
        </div>
        <p class="text-sm text-base-content/70">
          {gettext(
            "Link a folder on this computer so new imports keep originals in place. Thumbnails stay in the app uploads folder."
          )}
        </p>

        <div :if={@directory} class="flex flex-col gap-1 text-sm">
          <div>
            <span class="font-semibold">{gettext("Root:")}</span>
            <span id="competition-directory-root" class="font-mono break-all">{@directory.root_path}</span>
          </div>
          <div :if={@linked_slides_count > 0} class="text-base-content/70">
            {gettext("%{count} linked slide(s) in this competition.", count: @linked_slides_count)}
          </div>
        </div>

        <div
          :if={@link_mode}
          id="competition-directory-browser"
          class="border border-base-300 rounded-box p-3"
        >
          <div class="flex items-center gap-2 mb-2">
            <button
              id="competition-directory-level-up"
              type="button"
              class="btn btn-ghost btn-xs"
              phx-click="level-up"
              phx-target={@myself}
              aria-label={gettext("Level up")}
            >
              <Heroicons.icon name="arrow-up" type="outline" class="w-4 h-4" />
            </button>
            <p class="text-xs font-mono break-all">{@browser_cwd}</p>
          </div>
          <div class="flex flex-col max-h-40 overflow-y-auto tiny-scrollbar">
            <button
              :for={%{name: name} <- @browser_items}
              type="button"
              phx-click="level-down"
              phx-value-item={name}
              phx-target={@myself}
              class="btn btn-ghost btn-xs justify-start transition-colors"
            >
              <Heroicons.icon name="folder" type="outline" class="w-4 h-4 text-base-content/60" />
              {name}
            </button>
            <p :if={@browser_items == []} class="text-xs text-base-content/60 px-2 py-1">
              {gettext("No subfolders")}
            </p>
          </div>
          <p :if={@directory && @linked_slides_count > 0} class="text-xs text-warning mt-2">
            {gettext(
              "Linked slides will be looked up in the new folder: pick a copy that keeps the same participant subfolders."
            )}
          </p>
          <div class="flex flex-wrap gap-2 mt-3">
            <button
              id="competition-directory-use-folder"
              type="button"
              class="btn btn-primary btn-sm"
              phx-click="link-directory"
              phx-target={@myself}
              phx-disable-with={gettext("Linking…")}
            >
              {gettext("Use this folder")}
            </button>
            <button
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="cancel-link"
              phx-target={@myself}
            >
              {gettext("Cancel")}
            </button>
          </div>
        </div>

        <div :if={!@link_mode} class="flex flex-wrap gap-2">
          <button
            id="competition-directory-link"
            type="button"
            class={["btn btn-sm", if(@directory, do: "btn-outline", else: "btn-primary")]}
            phx-click="start-link"
            phx-target={@myself}
          >
            <Heroicons.icon name="folder-plus" type="outline" class="w-4 h-4" />
            {if @directory, do: gettext("Change folder…"), else: gettext("Link directory…")}
          </button>
          <button
            :if={@directory}
            id="competition-directory-rescan"
            type="button"
            class="btn btn-outline btn-sm"
            phx-click="rescan"
            phx-target={@myself}
            phx-disable-with={gettext("Scanning…")}
          >
            <Heroicons.icon name="arrow-path" type="outline" class="w-4 h-4" />
            {gettext("Rescan folders")}
          </button>
          <button
            :if={@directory}
            id="competition-directory-unlink"
            type="button"
            class="btn btn-outline btn-sm btn-error"
            phx-click="unlink-directory"
            phx-target={@myself}
            disabled={@linked_slides_count > 0}
            aria-describedby={@linked_slides_count > 0 && "competition-directory-unlink-hint"}
          >
            {gettext("Unlink")}
          </button>
        </div>

        <p
          :if={@directory && @linked_slides_count > 0}
          id="competition-directory-unlink-hint"
          class="text-xs text-base-content/60"
        >
          {gettext("Remove all linked slides before unlinking the directory.")}
        </p>

        <div
          :if={@directory && @participants != []}
          id="participant-folders-collapse"
          class={[
            "collapse collapse-arrow border border-base-300 rounded-box bg-base-100 mt-2",
            @participant_folders_open? && "collapse-open"
          ]}
        >
          <input
            type="checkbox"
            class="peer"
            checked={@participant_folders_open?}
            phx-click="toggle-participant-folders"
            phx-target={@myself}
          />
          <div class="collapse-title font-semibold text-sm min-h-12 py-3">
            {gettext("Participant folders")}
            <span class="font-normal text-base-content/60">
              — {gettext("manual override")}
            </span>
          </div>
          <div class="collapse-content">
            <p class="text-xs text-base-content/60 mb-3">
              {gettext(
                "Usually assigned automatically when you import from a folder inside the competition directory."
              )}
            </p>
            <ul class="flex flex-col gap-2 max-h-72 overflow-y-auto tiny-scrollbar">
              <li :for={p <- @participants} class="flex flex-col sm:flex-row sm:items-center gap-2">
                <label
                  for={"participant-folder-input-#{p.user_id}"}
                  class="text-sm shrink-0 sm:w-56 truncate"
                >
                  {p.number} — {p.user.first_name} {p.user.last_name}
                </label>
                <.form
                  for={%{}}
                  id={"participant-folder-#{p.user_id}"}
                  phx-submit="assign-folder"
                  phx-target={@myself}
                  class="flex-1"
                >
                  <input type="hidden" name="user_id" value={p.user_id} />
                  <div class="flex gap-2">
                    <input
                      id={"participant-folder-input-#{p.user_id}"}
                      type="text"
                      name="folder"
                      value={p.originals_folder || ""}
                      placeholder={gettext("Relative folder under root")}
                      class="input input-bordered input-sm flex-1 font-mono"
                    />
                    <button
                      type="submit"
                      class="btn btn-sm btn-outline"
                      phx-disable-with={gettext("Saving…")}
                    >
                      {gettext("Save")}
                    </button>
                  </div>
                </.form>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       link_mode: false,
       browser_cwd: nil,
       browser_items: [],
       participant_folders_open?: false
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(Map.take(assigns, [:id, :competition_id, :participants, :originals_status]))
     |> load_directory()}
  end

  @impl true
  def handle_event("toggle-participant-folders", _params, socket) do
    {:noreply, update(socket, :participant_folders_open?, &(!&1))}
  end

  def handle_event("start-link", _params, socket) do
    start_dir = link_browser_start_dir(socket.assigns.directory)
    {:ok, cwd} = FileBrowser.cd(start_dir)
    {:noreply, socket |> assign(link_mode: true) |> browse(cwd)}
  end

  def handle_event("cancel-link", _params, socket) do
    {:noreply, assign(socket, link_mode: false)}
  end

  def handle_event("level-up", _params, socket) do
    {:ok, cwd} = FileBrowser.cd(socket.assigns.browser_cwd, "..")
    {:noreply, browse(socket, cwd)}
  end

  def handle_event("level-down", %{"item" => item}, socket) do
    {:ok, cwd} = FileBrowser.cd(socket.assigns.browser_cwd, item)
    {:noreply, browse(socket, cwd)}
  end

  def handle_event("link-directory", _params, socket) do
    case CompetitionDirectories.link_root(socket.assigns.competition_id, socket.assigns.browser_cwd) do
      {:ok, _directory} ->
        send(self(), {:refresh, :participants})
        {:noreply, socket |> assign(link_mode: false) |> load_directory()}

      {:error, reason} ->
        flash_error(reason)
        {:noreply, socket}
    end
  end

  def handle_event("unlink-directory", _params, socket) do
    with {:error, reason} <- CompetitionDirectories.unlink_root(socket.assigns.competition_id) do
      flash_error(reason)
    end

    {:noreply, load_directory(socket)}
  end

  def handle_event("rescan", _params, socket) do
    competition_id = socket.assigns.competition_id

    with :reachable <- CompetitionDirectories.check_reachability_with_timeout(competition_id),
         {:ok, count} <- CompetitionDirectories.reconcile_participant_folders(competition_id) do
      send(self(), {:flash, :info, gettext("Rescan complete. Updated %{count} folder(s).", count: count)})
      send(self(), {:refresh, :participants})
    else
      {:error, reason} -> flash_error(reason)
      _unreachable -> flash_error(:not_found)
    end

    {:noreply, load_directory(socket)}
  end

  def handle_event("assign-folder", %{"user_id" => user_id, "folder" => folder}, socket) do
    folder = String.trim(folder)

    folder_path =
      if Path.type(folder) == :absolute do
        folder
      else
        Path.join(socket.assigns.directory.root_path, folder)
      end

    case CompetitionDirectories.assign_participant_folder(socket.assigns.competition_id, user_id, folder_path) do
      {:ok, _participant} ->
        send(self(), {:flash, :info, gettext("Participant folder saved.")})
        send(self(), {:refresh, :participants})

      {:error, reason} ->
        flash_error(reason)
    end

    {:noreply, load_directory(socket)}
  end

  defp link_browser_start_dir(%{root_path: root_path}) do
    parent = Path.dirname(root_path)

    if File.dir?(parent) and parent not in ["/", "."] do
      parent
    else
      user_home_dir()
    end
  end

  defp link_browser_start_dir(_), do: user_home_dir()

  defp user_home_dir do
    home = System.user_home()

    if is_binary(home) and File.dir?(home) do
      home
    else
      Path.expand("~/")
    end
  end

  defp browse(socket, cwd), do: assign(socket, browser_cwd: cwd, browser_items: list_dirs(cwd))

  defp list_dirs(cwd) do
    cwd |> FileBrowser.ls!() |> Enum.filter(&(&1.type == :dir))
  rescue
    File.Error -> []
  end

  defp load_directory(socket) do
    competition_id = socket.assigns.competition_id

    directory =
      case CompetitionDirectories.get(competition_id) do
        {:ok, directory} -> directory
        {:error, :not_linked} -> nil
      end

    assign(socket,
      directory: directory,
      linked_slides_count: CompetitionDirectories.count_linked_slides(competition_id)
    )
  end

  defp flash_error(reason) do
    Logger.warning("Competition directory operation failed: #{inspect(reason)}")
    send(self(), {:flash, :error, error_message(reason)})
  end

  defp error_message(:escapes_root), do: gettext("Folder must stay inside the competition root.")
  defp error_message(:enoent), do: gettext("Folder not found.")
  defp error_message(:linked_slides_remain), do: gettext("Remove linked slides before unlinking.")
  defp error_message(:not_found), do: gettext("Competition directory not found on any connected drive.")

  defp error_message(:invalid_manifest), do: gettext("This folder contains an unreadable Safari Manager marker file.")

  defp error_message(:manifest_not_writable), do: gettext("Could not write the marker file: is the folder read-only?")

  defp error_message(:invalid), do: gettext("Choose an existing folder other than the filesystem root.")
  defp error_message(_reason), do: gettext("Operation failed.")

  defp reachability_label(:reachable), do: gettext("Reachable")
  defp reachability_label(:unreachable), do: gettext("Unreachable")
  defp reachability_label(_), do: gettext("Unknown")

  defp status_badge_class(:reachable), do: "badge-success"
  defp status_badge_class(:unreachable), do: "badge-warning"
  defp status_badge_class(_), do: "badge-ghost"
end
