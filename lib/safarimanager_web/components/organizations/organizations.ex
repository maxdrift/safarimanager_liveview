defmodule SMWeb.Organizations do
  @moduledoc """
  Organizations live view
  """
  use Surface.LiveView

  require Logger

  alias SM.Organizations
  alias SMWeb.Components.ConfirmationDialog
  alias SMWeb.Components.Organizations.Edit
  alias SMWeb.Components.Organizations.List
  alias SMWeb.Components.Organizations.Show
  alias Surface.Components.LivePatch

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _ = subscribe(socket)

    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle-select-item", %{"id" => id, "selected" => selected?}, socket) do
    items =
      Enum.map(socket.assigns.items, fn
        %_{id: ^id} = item ->
          Map.put(item, :selected?, String.to_existing_atom(selected?))

        item ->
          item
      end)

    socket =
      socket
      |> assign(:items, items)
      |> update_selection(items)

    {:noreply, socket}
  end

  def handle_event("toggle-select-all", _, socket) do
    items =
      if socket.assigns.all_selected? do
        socket.assigns.items
        |> Enum.map(fn item ->
          Map.put(item, :selected?, false)
        end)
      else
        socket.assigns.items
        |> Enum.map(fn item ->
          Map.put(item, :selected?, true)
        end)
      end

    socket =
      socket
      |> assign(:items, items)
      |> update_selection(items)

    {:noreply, socket}
  end

  def handle_event("delete-one", %{"id" => id}, socket) do
    ConfirmationDialog.show("delete-confirmation")
    {:noreply, assign(socket, :to_be_deleted, [id])}
  end

  def handle_event("delete-many", %{}, socket) do
    ConfirmationDialog.show("delete-confirmation")
    {:noreply, assign(socket, :to_be_deleted, socket.assigns.selected)}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [_ | _] = ids}} = socket)
      when is_list(ids) do
    # TODO: Handle deletion errors
    delete(ids)

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [id]}} = socket) do
    # TODO: Handle deletion error
    delete(id)

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("abort", %{}, socket) do
    ConfirmationDialog.hide("delete-confirmation")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"action" => "new"}, _url, socket) do
    Edit.show("edit-dialog")
    {:noreply, socket}
  end

  def handle_params(%{"id" => id, "action" => "edit"}, _url, socket) do
    Edit.show("edit-dialog", id)
    {:noreply, socket}
  end

  def handle_params(%{"id" => id, "action" => "show"}, _url, socket) do
    case get(id) do
      {:ok, organization} ->
        Show.show("show-dialog", organization)

      {:error, reason} = error ->
        Logger.error("Error showing Organization: #{inspect(reason)}")
        error
    end

    {:noreply, socket}
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Organizations, [:organization, _], _}, socket) do
    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:noreply, socket}
  end

  # Internal

  defp list do
    Organizations.list()
  end

  defp get(id) do
    Organizations.get(id)
  end

  defp delete(ids) when is_list(ids) do
    case Organizations.delete_many(ids) do
      {:ok, deleted} ->
        IO.puts("Deleted #{deleted} entities")
        :ok

      :error ->
        # TODO: return error to UI
        Logger.error("""
        Error deleting multiple Organizations:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end
  end

  defp delete(id) do
    with {:ok, organization} <- Organizations.get(id),
         {:ok, _result} <- Organizations.delete(organization) do
      :ok
    else
      {:error, reason} = error ->
        # TODO: return error to UI
        Logger.error("Error deleting Organization #{inspect(id)}: #{inspect(reason)}")
        error
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Organizations.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Organizations updates: #{inspect(reason)}")
          error
      end
    end
  end

  defp load_entities(socket) do
    items =
      Enum.map(list(), fn item ->
        Map.put(item, :selected?, false)
      end)

    assign(socket, :items, items)
  end

  defp update_selection(socket, items) do
    socket
    |> assign(:selected, Enum.filter(items, & &1.selected?) |> Enum.map(& &1.id))
    |> assign(:all_selected?, Enum.all?(items, & &1.selected?))
    |> assign(:any_selected?, Enum.any?(items, & &1.selected?))
  end

  defp reset_selection(socket) do
    socket
    |> assign(:selected, [])
    |> assign(:to_be_deleted, [])
    |> assign(:all_selected?, false)
    |> assign(:any_selected?, false)
  end
end
