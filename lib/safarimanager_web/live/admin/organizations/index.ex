defmodule SMWeb.Live.Admin.Organizations.Index do
  @moduledoc """
  Organizations live view
  """
  use SMWeb, :surface_view

  alias SM.Organizations
  alias SM.Organizations.Organization
  alias SMWeb.Components.Column
  alias SMWeb.Components.DateTimeString
  alias SMWeb.Components.FieldsList
  alias SMWeb.Components.FieldsListItem
  alias SMWeb.Components.Grid
  alias SMWeb.Components.Layout
  alias SMWeb.Components.ShortUUID
  alias SMWeb.Components.SMField
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput
  alias Surface.Components.LivePatch

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = subscribe(socket)

    changeset_action = SMWeb.live_action_to_changeset_action(socket.assigns.live_action)

    socket =
      socket
      |> load_entities()
      |> reset_current_editing()
      |> assign(action: changeset_action, merge_selection: [])

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  # Create/Edit dialog validate callback
  def handle_event("validate", %{"entity" => params}, socket) do
    changeset =
      socket.assigns.record
      |> change(params)
      |> Map.put(:action, :validate)

    socket = assign(socket, :changeset, changeset)
    {:noreply, socket}
  end

  def handle_event("validate", %{"merge" => %{"dest_id" => dest_id}}, socket) do
    changeset =
      socket.assigns.merge_selection
      |> Enum.map(& &1.id)
      |> Organizations.merge_changeset(dest_id)
      |> Map.put(:action, :validate)

    socket = assign(socket, :changeset, changeset)
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

        socket = put_flash(socket, :info, gettext("Organization created successfully"))
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event(
        "submit",
        %{"entity" => %{"_action" => "edit"} = params},
        socket
      ) do
    case Organizations.update(socket.assigns.record, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/organizations")

        socket = put_flash(socket, :info, ~s(#{gettext("Edited organization")} "#{entity.name}"))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("submit", %{"merge" => %{"dest_id" => dest_id}}, socket) do
    selected_ids = Enum.map(socket.assigns.merge_selection, & &1.id)

    socket =
      case Organizations.merge(selected_ids, dest_id) do
        {:ok, _organization} ->
          put_flash(socket, :info, gettext("Successfully merged organizations"))

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
            gettext("Error merging organizations: a destination must be specified")
          )

        {:error, reason} ->
          Logger.error(
            "Unable to merge organizations #{inspect(selected_ids)} into #{dest_id}: #{inspect(reason)}"
          )

          put_flash(socket, :error, gettext("Error merging organizations"))
      end

    socket =
      socket
      |> reset_current_editing()
      |> assign(merge_selection: [])
      |> push_patch(to: "/admin/organizations")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Organizations.get(id) do
      {:ok, organization} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, record: organization)}

          :edit ->
            changeset = change(organization, %{})

            socket =
              socket
              |> assign(
                record: organization,
                changeset: changeset,
                action: :edit
              )

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this Organization"))
        Logger.error("Error retrieving Organization #{id}: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_params(_params, _url, socket) do
    case socket.assigns.live_action do
      :index ->
        {:noreply, socket}

      :new ->
        socket =
          socket
          |> reset_current_editing()
          |> assign(action: :create)

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({"delete-one", id}, socket) do
    socket =
      case delete(id) do
        :ok -> put_flash(socket, :info, gettext("Organization deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete Organization"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        :ok ->
          put_flash(socket, :info, gettext("Organizations deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Organizations"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Organizations.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All organizations deleted successfully"))}
  end

  def handle_info({"merge-selected", selection}, socket) do
    selection =
      Organizations.list()
      |> Enum.filter(fn org -> org.id in selection end)

    {:noreply, assign(socket, merge_selection: selection)}
  end

  def handle_info({Organizations, [:organization, :deleted], deleted_ids}, socket)
      when is_list(deleted_ids) do
    socket =
      deleted_ids
      |> Stream.map(fn id -> "items-#{id}" end)
      |> Stream.scan(socket, fn dom_id, socket ->
        stream_delete_by_dom_id(socket, :items, dom_id)
      end)
      |> Enum.reverse()
      |> hd()

    {:noreply, socket}
  end

  def handle_info({Organizations, [:organization, :deleted], deleted_count}, socket)
      when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/organizations")}
  end

  def handle_info({Organizations, [:organization, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Organizations, [:organization, :updated], updated_item}, socket) do
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Organizations, [:organization, :created], inserted_item}, socket) do
    _socket =
      if is_nil(Map.get(socket.assigns, :last_id)) do
        {:noreply, stream_insert(socket, :items, inserted_item)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(organization, params) do
    Organizations.change(organization, params)
  end

  defp delete(ids) when is_list(ids) do
    case Organizations.delete_many(ids) do
      {:ok, ids} ->
        Logger.debug("Deleted #{Enum.count(ids)} entities")
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
    items = Organizations.list()

    stream(socket, :items, items)
  end

  defp reset_current_editing(socket) do
    entity = %Organization{}

    changeset = change(entity, %{})

    socket
    |> assign(:record, entity)
    |> assign(:changeset, changeset)
  end
end
