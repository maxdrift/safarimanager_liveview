defmodule SMWeb.Components.Admin.Organizations do
  @moduledoc """
  Organizations live view
  """
  use SMWeb, :surface_view

  alias SM.Organizations
  alias SM.Organizations.Organization
  alias SMWeb.Components.Admin.Organizations.Edit
  alias SMWeb.Components.Admin.Organizations.List
  alias SMWeb.Components.Admin.Organizations.Merge
  alias SMWeb.Components.Admin.Organizations.Show
  alias SMWeb.Components.ConfirmationDialog
  alias SMWeb.Components.Layout
  alias Surface.Components.Link
  alias Surface.Components.LivePatch

  require Logger

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
    selected? = String.to_existing_atom(selected?)
    all_items = socket.assigns.items
    selected_items = socket.assigns.selected

    items =
      all_items
      |> Map.update!(id, fn item ->
        Map.put(item, :selected, selected?)
      end)

    selected_items =
      if selected? do
        MapSet.put(selected_items, id)
      else
        MapSet.delete(selected_items, id)
      end

    selected_count = MapSet.size(selected_items)

    socket =
      assign(
        socket,
        items: items,
        selected: selected_items,
        all_selected?: selected_count == Enum.count(all_items),
        any_selected?: selected_count > 0
      )

    {:noreply, socket}
  end

  def handle_event("toggle-select-all", _value, %{assigns: %{all_selected?: true}} = socket) do
    items =
      socket.assigns.items
      |> Enum.map(fn {id, value} ->
        {id, %{value | selected: false}}
      end)
      |> Enum.into(%{})

    socket =
      socket
      |> assign(
        items: items,
        selected: MapSet.new(),
        all_selected?: false,
        any_selected?: false
      )

    {:noreply, socket}
  end

  def handle_event("toggle-select-all", _value, %{assigns: %{all_selected?: false}} = socket) do
    items =
      socket.assigns.items
      |> Enum.map(fn {id, value} ->
        {id, %{value | selected: true}}
      end)
      |> Enum.into(%{})

    socket =
      socket
      |> assign(
        items: items,
        selected: MapSet.new(socket.assigns.ordered_ids),
        all_selected?: true,
        any_selected?: true
      )

    {:noreply, socket}
  end

  def handle_event("delete-one", %{"id" => id}, socket) do
    ConfirmationDialog.show("delete-confirmation")
    {:noreply, assign(socket, :to_be_deleted, [id])}
  end

  def handle_event("delete-many", %{}, socket) do
    ConfirmationDialog.show("delete-confirmation")
    {:noreply, assign(socket, :to_be_deleted, MapSet.to_list(socket.assigns.selected))}
  end

  def handle_event("merge-many", %{}, socket) do
    Merge.show("merge-dialog")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [id]}} = socket) do
    socket =
      case delete(id) do
        :ok -> put_flash(socket, :info, "Organization deleted successfully")
        :error -> put_flash(socket, :error, "Unable to delete Organization")
      end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [_ | _] = ids}} = socket) do
    socket =
      case delete(ids) do
        :ok -> put_flash(socket, :info, "Organizations deleted successfully")
        :error -> put_flash(socket, :error, "Unable to delete Organizations")
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

  def handle_event("validate", %{"merge" => %{"dest_id" => dest_id}}, socket) do
    changeset =
      socket.assigns.selected
      |> MapSet.to_list()
      |> Organizations.merge_changeset(dest_id)
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
    case Organizations.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/organizations")

        Edit.hide("edit-dialog")
        socket = put_flash(socket, :info, "Organization created successfully")
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
    case Organizations.update(socket.assigns.editing_entity, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/organizations")

        Edit.hide("edit-dialog")

        socket = put_flash(socket, :info, ~s(Edited organization "#{entity.name}"))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("merge", %{"merge" => %{"dest_id" => dest_id}}, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected) -- [dest_id]

    socket =
      case Organizations.merge(selected_ids, dest_id) do
        {:ok, _organization} ->
          put_flash(socket, :info, "Successfully merged organizations")

        {:error,
         %Ecto.Changeset{
           valid?: false,
           errors: [dest_id: {"can't be blank", [validation: :required]}]
         }} ->
          Logger.error(
            "Unable to merge organizations #{inspect(selected_ids)}: a destination must be specified"
          )

          put_flash(
            socket,
            :error,
            "Error merging organizations: a destination must be specified"
          )

        {:error, reason} ->
          Logger.error(
            "Unable to merge organizations #{inspect(selected_ids)} into #{dest_id}: #{inspect(reason)}"
          )

          put_flash(socket, :error, "Error merging organizations")
      end

    socket =
      socket
      |> reset_current_editing()
      |> push_patch(to: "/admin/organizations")

    Merge.hide("merge-dialog")
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"action" => "new"}, _url, socket) do
    Edit.show("edit-dialog", :create)

    {:noreply, reset_current_editing(socket)}
  end

  def handle_params(%{"id" => id, "action" => "edit"}, _url, socket) do
    case get(id) do
      {:ok, organization} ->
        changeset = change(organization, %{})
        Edit.show("edit-dialog", :edit)

        socket =
          socket
          |> assign(:editing_entity, organization)
          |> assign(:editing_changeset, changeset)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error showing Edit modal: #{inspect(reason)}")
        socket = put_flash(socket, :error, "Unable to edit this Organization")
        {:noreply, socket}
    end
  end

  def handle_params(%{"id" => id, "action" => "show"}, _url, socket) do
    case get(id) do
      {:ok, organization} ->
        Show.show("show-dialog", organization)

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Unable to show this Organization")
        Logger.error("Error showing Organization: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Organizations, [:organization, _action], _result}, socket) do
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

  defp new do
    %Organization{}
  end

  defp change(organization, params) do
    Organizations.change(organization, params)
  end

  defp delete(ids) when is_list(ids) do
    case Organizations.delete_many(ids) do
      {:ok, deleted} ->
        IO.puts("Deleted #{deleted} entities")
        :ok

      :error ->
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
      {:error, reason} ->
        Logger.error("Error deleting Organization #{inspect(id)}: #{inspect(reason)}")
        :error
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
    ordered_entities = list()
    ordered_ids = Enum.map(ordered_entities, & &1.id)

    items =
      ordered_entities
      |> Enum.map(fn item ->
        {item.id, %{data: item, selected: false}}
      end)
      |> Enum.into(%{})

    assign(socket,
      ordered_ids: ordered_ids,
      items: items,
      selected: MapSet.new()
    )
  end

  defp reset_current_editing(socket) do
    entity = new()

    changeset = change(entity, %{})

    socket
    |> assign(:editing_entity, entity)
    |> assign(:editing_changeset, changeset)
  end

  defp reset_selection(socket) do
    socket
    |> assign(:selected, MapSet.new())
    |> assign(:to_be_deleted, [])
    |> assign(:all_selected?, false)
    |> assign(:any_selected?, false)
  end
end
