defmodule SMWeb.Live.Admin.Categories do
  @moduledoc """
  Categories live view
  """
  use SMWeb, :surface_view

  alias SM.Categories
  alias SM.Categories.Category
  alias SMWeb.Live.Admin.Categories.Edit
  alias SMWeb.Live.Admin.Categories.List
  alias SMWeb.Live.Admin.Categories.Show
  alias SMWeb.Components.ConfirmationDialog
  alias SMWeb.Components.Layout
  alias Surface.Components.Link
  alias Surface.Components.LivePatch

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = subscribe(socket)

    socket =
      socket
      |> load_entities()
      |> reset_current_editing()
      |> reset_selection()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle-select-item", %{"id" => id, "selected" => selected?}, socket) do
    items =
      Enum.map(socket.assigns.items, fn
        %_struct{id: ^id} = item ->
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

  def handle_event("toggle-select-all", _value, socket) do
    items =
      if socket.assigns.all_selected? do
        Enum.map(socket.assigns.items, fn item ->
          Map.put(item, :selected?, false)
        end)
      else
        Enum.map(socket.assigns.items, fn item ->
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

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [id]}} = socket) do
    socket =
      case delete(id) do
        :ok -> put_flash(socket, :info, "Category deleted successfully")
        :error -> put_flash(socket, :error, "Unable to delete Category")
      end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [_ | _] = ids}} = socket) do
    socket =
      case delete(ids) do
        :ok -> put_flash(socket, :info, "Categories deleted successfully")
        :error -> put_flash(socket, :error, "Unable to delete Categories")
      end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("abort", %{}, socket) do
    ConfirmationDialog.hide("delete-confirmation")

    {:noreply, socket}
  end

  # Create/Edit dialog validate callback
  def handle_event("validate", %{"entity" => params}, socket) do
    changeset =
      socket.assigns.editing_entity
      |> change(params)
      |> Map.put(:action, :validate)

    socket = assign(socket, :editing_changeset, changeset)
    {:noreply, socket}
  end

  # Create/Edit dialog submit callback
  def handle_event(
        "submit",
        %{"entity" => %{"_action" => "create"} = params},
        socket
      ) do
    case Categories.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/categories")

        Edit.hide("edit-dialog")
        socket = put_flash(socket, :info, "Category created successfully")
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :editing_changeset, changeset)}
    end
  end

  def handle_event(
        "submit",
        %{"entity" => %{"_action" => "edit"} = params},
        socket
      ) do
    case Categories.update(socket.assigns.editing_entity, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/categories")

        Edit.hide("edit-dialog")

        socket = put_flash(socket, :info, ~s(Edited category "#{entity.name}"))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"action" => "new"}, _url, socket) do
    Edit.show("edit-dialog", :create)

    {:noreply, reset_current_editing(socket)}
  end

  def handle_params(%{"id" => id, "action" => "edit"}, _url, socket) do
    case get(id) do
      {:ok, category} ->
        changeset = change(category, %{})
        Edit.show("edit-dialog", :edit)

        socket =
          socket
          |> assign(:editing_entity, category)
          |> assign(:editing_changeset, changeset)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error showing Edit modal: #{inspect(reason)}")
        socket = put_flash(socket, :error, "Unable to edit this Category")
        {:noreply, socket}
    end
  end

  def handle_params(%{"id" => id, "action" => "show"}, _url, socket) do
    case get(id) do
      {:ok, category} ->
        Show.show("show-dialog", category)

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Unable to show this Category")
        Logger.error("Error showing Category: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Categories, [:category, _action], _result}, socket) do
    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:noreply, socket}
  end

  # Internal

  defp list do
    Categories.list()
  end

  defp get(id) do
    Categories.get(id)
  end

  defp new do
    %Category{}
  end

  defp change(category, params) do
    Categories.change(category, params)
  end

  defp delete(ids) when is_list(ids) do
    case Categories.delete_many(ids) do
      {:ok, deleted} ->
        Logger.debug("Deleted #{deleted} entities")
        :ok

      :error ->
        Logger.error("""
        Error deleting multiple Categories:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end
  end

  defp delete(id) do
    with {:ok, category} <- Categories.get(id),
         {:ok, _result} <- Categories.delete(category) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Error deleting Category #{inspect(id)}: #{inspect(reason)}")
        :error
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Categories.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Categories updates: #{inspect(reason)}")
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

  defp reset_current_editing(socket) do
    entity = new()

    changeset = change(entity, %{})

    socket
    |> assign(:editing_entity, entity)
    |> assign(:editing_changeset, changeset)
  end

  defp update_selection(socket, items) do
    selected =
      items
      |> Enum.filter(& &1.selected?)
      |> Enum.map(& &1.id)

    socket
    |> assign(:selected, selected)
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
