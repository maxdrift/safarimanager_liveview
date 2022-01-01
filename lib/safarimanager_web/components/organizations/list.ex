defmodule SMWeb.Organizations.List do
  @moduledoc """
  Organizations list component
  """
  use Surface.LiveView

  require Logger

  alias SM.Organizations
  alias SMWeb.Components.ConfirmationDialog
  alias SMWeb.Components.Organizations.Edit
  alias SMWeb.Components.Organizations.Show
  alias Surface.Components.LivePatch

  prop items, :list, required: true

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Organizations.subscribe()

    socket =
      socket
      |> assign_entities()
      |> assign(:selected, [])
      |> assign(:all_selected?, false)
      |> assign(:any_selected?, false)

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
      |> assign(:selected, Enum.filter(items, & &1.selected?) |> Enum.map(& &1.id))
      |> assign(:all_selected, Enum.all?(items, & &1.selected?))
      |> assign(:any_selected?, Enum.any?(items, & &1.selected?))

    {:noreply, socket}
  end

  def handle_event("toggle-select-all", _, socket) do
    items =
      if Enum.any?(socket.assigns.items, fn item -> item.selected? end) do
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
      |> assign(:selected, Enum.filter(items, & &1.selected?) |> Enum.map(& &1.id))
      |> assign(:all_selected?, Enum.all?(items, & &1.selected?))
      |> assign(:any_selected?, Enum.any?(items, & &1.selected?))

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
    case Organizations.delete_many(ids) do
      {:ok, deleted} ->
        IO.puts("Deleted #{deleted} entities")

      :error ->
        # TODO: return error to UI
        Logger.error("""
        Error deleting multiple Organizations:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [id]}} = socket) do
    with {:ok, organization} <- Organizations.get(id),
         {:ok, _result} <- Organizations.delete(organization) do
    else
      {:error, reason} ->
        # TODO: return error to UI
        Logger.error("Error deleting Organization #{inspect(id)}: #{inspect(reason)}")
    end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("abort", %{}, socket) do
    items = socket.assigns.items

    socket
    |> assign(:to_be_deleted, [])
    |> assign(:selected, Enum.filter(items, & &1.selected?) |> Enum.map(& &1.id))
    |> assign(:all_selected?, Enum.all?(items, & &1.selected?))
    |> assign(:any_selected?, Enum.any?(items, & &1.selected?))

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
    Show.show("show-dialog", id)
    {:noreply, socket}
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Organizations, [:organization, _], _}, socket) do
    items =
      Enum.map(Organizations.list(), fn item ->
        Map.put(item, :selected?, false)
      end)

    socket =
      socket
      |> assign(:items, items)
      |> assign(:selected, [])
      |> assign(:to_be_deleted, [])
      |> assign(:all_selected?, false)
      |> assign(:any_selected?, false)

    {:noreply, socket}
  end

  # Internal

  defp assign_entities(socket) do
    items =
      Enum.map(Organizations.list(), fn item ->
        Map.put(item, :selected?, false)
      end)

    assign(socket, :items, items)
  end

  defp format_id(id) do
    id
    |> String.split_at(7)
    |> Tuple.to_list()
    |> hd()
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
