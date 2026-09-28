defmodule SMWeb.Components.FileBrowser do
  @moduledoc """
  File browser component.
  """
  use SMWeb, :live_component

  alias SM.Cache
  alias SM.FileBrowser

  require Logger

  attr :file_filter, :list, default: []
  attr :import_click, :string
  attr :user_id, :string, default: nil
  attr :start_cwd, :string, default: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div class="my-2">
        <progress
          class={[
            "progress",
            "progress-secondary",
            Decimal.equal?(Decimal.rem(@upload_progress, 1), 0) && "invisible"
          ]}
          value={Decimal.mult(@upload_progress, 100) |> Decimal.round()}
          max="100"
        />
      </div>
      <div class="text-xl font-bold text-center">
        {gettext("File browser")}
      </div>
      <p :if={@cwd} class="text-xs font-mono text-center text-base-content/60 break-all px-2">
        {@cwd}
      </p>
      <div class="my-6">
        <div>
          <button phx-click="level-up" class="btn btn-outline btn-xs gap-1" phx-target={@myself}>
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
          <div :for={%{type: type, name: item, selectable: selectable} <- @items}>
            <button
              :if={type == :dir}
              phx-click="level-down"
              phx-value-item={item}
              class="btn btn-ghost btn-xs gap-1"
              phx-target={@myself}
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
              phx-click="select"
              phx-value-item={item}
              class={["btn", "btn-link", "btn-xs", "gap-1", not selectable && "btn-disabled"]}
              phx-target={@myself}
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
        </div>
      </div>
      <div class="w-full">
        <button
          class={["btn", "btn-primary", not can_import?(@user_id, @items) && "btn-disabled"]}
          phx-click={@import_click}
          phx-value-cwd={@cwd}
          phx-value-items={
            @items
            |> Enum.flat_map(fn
              %{selectable: true, type: :dir} -> []
              %{selectable: true, type: _not_dir} = item -> [item.name]
              %{selectable: false} -> []
            end)
            |> Enum.join(",")
          }
        >
          {gettext("Import all")}<span :if={can_import?(@user_id, @items)}>&nbsp;{count_selectable_files(
            @items
          )} {gettext("files")}</span>
        </button>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def update(%{navigate: :parent} = assigns, socket) do
    file_filter = assigns[:file_filter] || socket.assigns[:file_filter] || []
    cwd = parent_dir(socket.assigns[:cwd])
    {:ok, _} = set_last_dir(cwd)
    dir_items = FileBrowser.ls!(cwd, filter: file_filter)

    {:ok,
     socket
     |> assign(Map.delete(assigns, :navigate))
     |> assign(cwd: cwd, items: dir_items)}
  end

  def update(%{file_filter: file_filter} = assigns, socket) do
    previous_user = socket.assigns[:user_id]
    new_user = Map.get(assigns, :user_id)
    start_cwd = Map.get(assigns, :start_cwd) || socket.assigns[:start_cwd]
    reset_for_user? = not is_nil(new_user) and new_user != previous_user

    cwd =
      if reset_for_user? do
        preferred_start_dir(start_cwd)
      else
        current_or_preferred_dir(socket, start_cwd)
      end

    {:ok, _} = set_last_dir(cwd)
    dir_items = FileBrowser.ls!(cwd, filter: file_filter)

    progress =
      Map.get(assigns, :upload_progress) || socket.assigns[:upload_progress] || Decimal.new(0)

    {:ok,
     socket
     |> assign(Map.delete(assigns, :navigate))
     |> assign(cwd: cwd, items: dir_items, upload_progress: progress, start_cwd: start_cwd)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, Map.delete(assigns, :navigate))}
  end

  @impl Phoenix.LiveComponent
  def handle_event("level-down", %{"item" => item}, socket) do
    {:ok, cwd} = FileBrowser.cd(socket.assigns.cwd, item)
    dir_items = FileBrowser.ls!(cwd, filter: socket.assigns.file_filter)
    {:ok, _cwd} = set_last_dir(cwd)

    {:noreply, assign(socket, cwd: cwd, items: dir_items)}
  end

  def handle_event("level-up", _params, socket) do
    cwd = parent_dir(socket.assigns.cwd)
    dir_items = FileBrowser.ls!(cwd, filter: socket.assigns.file_filter)
    {:ok, _full_path} = set_last_dir(cwd)

    {:noreply, assign(socket, cwd: cwd, items: dir_items)}
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

  defp preferred_start_dir(start_cwd) when is_binary(start_cwd) do
    if File.dir?(start_cwd), do: Path.expand(start_cwd), else: home_dir()
  end

  defp preferred_start_dir(_), do: home_dir()

  defp current_or_preferred_dir(socket, start_cwd) do
    case socket.assigns[:cwd] do
      cwd when is_binary(cwd) ->
        if File.dir?(cwd), do: Path.expand(cwd), else: preferred_start_dir(start_cwd)

      _ ->
        preferred_start_dir(start_cwd)
    end
  end

  defp parent_dir(nil), do: home_dir()

  defp parent_dir(cwd) when is_binary(cwd) do
    parent = Path.dirname(Path.expand(cwd))
    if File.dir?(parent), do: parent, else: home_dir()
  end

  defp home_dir do
    home = System.user_home()

    if is_binary(home) and File.dir?(home) do
      home
    else
      Path.expand("~/")
    end
  end

  defp set_last_dir(path) do
    Cache.put(:last_dir, path)
    {:ok, path}
  end
end
