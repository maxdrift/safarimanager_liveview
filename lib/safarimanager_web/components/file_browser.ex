defmodule SMWeb.Components.FileBrowser do
  @moduledoc """
  File browser component.
  """
  use SMWeb, :surface_live_component

  alias SM.Cache
  alias SM.FileBrowser

  require Logger

  data cwd, :string
  data items, :list
  data upload_progress, :decimal, default: Decimal.new(0)
  prop file_filter, :list, default: []
  prop import_click, :event
  prop user_id, :string

  def render(assigns) do
    ~F"""
    <div {=@id}>
      <div class="my-2">
        <progress
          class={
            "progress",
            "progress-secondary",
            invisible: Decimal.equal?(Decimal.rem(@upload_progress, 1), 0)
          }
          value={Decimal.mult(@upload_progress, 100) |> Decimal.round()}
          max="100"
        />
      </div>
      <div class="text-xl font-bold text-center">
        {gettext("File browser")}
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
          {#for %{type: type, name: item, selectable: selectable} <- @items}
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
              <button
                :if={type != :dir}
                :on-click="select"
                :values={item: item}
                class={["btn", "btn-link", "btn-xs", "gap-1", "btn-disabled": not selectable]}
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
                    :if={type == :img}
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />

                  <path
                    :if={type == :txt}
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
                  />

                  <path
                    :if={type == :other}
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
                  />
                </svg>
                {Path.basename(item)}
              </button>
            </div>
          {/for}
        </div>
      </div>
      <div class="w-full">
        <button
          class={"btn", "btn-primary", "btn-disabled": not can_import?(@user_id, @items)}
          :on-click={@import_click}
          :values={
            cwd: @cwd,
            items:
              @items
              |> Enum.flat_map(fn
                %{selectable: true, type: :dir} -> []
                %{selectable: true, type: _not_dir} = item -> [item.name]
                %{selectable: false} -> []
              end)
              |> Enum.join(",")
          }
        >
          {gettext("Import all")}<span :if={can_import?(@user_id, @items)}>&nbsp;{count_selectable_files(@items)} {gettext("files")}</span>
        </button>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def update(%{file_filter: file_filter} = assigns, socket) do
    {:ok, cwd} =
      get_last_dir()
      |> Path.expand()
      |> FileBrowser.cd()

    dir_items = FileBrowser.ls!(cwd, filter: file_filter)

    assigns =
      assigns
      |> Map.to_list()
      |> Keyword.merge(
        cwd: cwd,
        items: dir_items
      )

    {:ok, assign(socket, assigns)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # Event handlers

  @impl Phoenix.LiveComponent
  def handle_event("level-down", %{"item" => item}, socket) do
    {:ok, cwd} = FileBrowser.cd(socket.assigns.cwd, item)
    dir_items = FileBrowser.ls!(cwd, filter: socket.assigns.file_filter)
    full_path = Path.dirname(cwd)
    {:ok, _full_path} = set_last_dir(full_path)

    socket =
      socket
      |> assign(:cwd, cwd)
      |> assign(:items, dir_items)

    {:noreply, socket}
  end

  def handle_event("level-up", _params, socket) do
    {:ok, cwd} = FileBrowser.cd(socket.assigns.cwd, "..")
    dir_items = FileBrowser.ls!(cwd, filter: socket.assigns.file_filter)
    {:ok, _full_path} = set_last_dir(cwd)

    socket =
      socket
      |> assign(:cwd, cwd)
      |> assign(:items, dir_items)

    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp count_selectable_files(items) do
    Enum.count(items, &(&1.selectable and &1.type != :dir))
  end

  defp can_import?(user_id, items) do
    not is_nil(user_id) and count_selectable_files(items) > 0
  end

  defp set_last_dir(path) do
    Cache.put(:last_dir, path)

    {:ok, path}
  end

  defp get_last_dir do
    with last_dir when not is_nil(last_dir) <- Cache.get(:last_dir),
         true <- File.exists?(last_dir) do
      last_dir
    else
      _nil_or_false ->
        Logger.warning("Unable to find last used directory path. Using home directory.")

        {:ok, path} =
          "~/"
          |> Path.expand()
          |> set_last_dir()

        path
    end
  end
end
