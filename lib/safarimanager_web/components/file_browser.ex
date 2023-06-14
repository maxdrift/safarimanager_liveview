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
