defmodule SMWeb.Live.Admin.Users.Index do
  @moduledoc """
  Users live view
  """
  use SMWeb, :surface_view

  import SMWeb.Components.DateTimeString
  import SMWeb.Components.FieldsList
  import SMWeb.Components.Layout
  import SMWeb.Components.ShortUUID
  import SMWeb.Components.SMField

  alias SM.Accounts
  alias SM.Accounts.User
  alias SM.Categories
  alias SM.Organizations
  alias SMWeb.Components.Column
  alias SMWeb.Components.Grid
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput

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
      |> assign(
        action: changeset_action,
        merge_selection: [],
        organizations: Organizations.list(),
        categories: Categories.list()
      )

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
      |> Accounts.merge_changeset(dest_id)
      |> Map.put(:action, :validate)

    socket = assign(socket, :changeset, changeset)
    {:noreply, socket}
  end

  # Create/Edit dialog submit callback
  def handle_event("submit", %{"entity" => %{"_action" => "create"} = params}, socket) do
    case Accounts.register_simplified_user(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/users")

        socket = put_flash(socket, :info, gettext("User created successfully"))
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("submit", %{"entity" => %{"_action" => "edit"} = params}, socket) do
    case Accounts.update(socket.assigns.record, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/users")

        socket =
          put_flash(
            socket,
            :info,
            ~s(#{gettext("Edited user")} "#{entity.first_name} #{entity.last_name}")
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("submit", %{"merge" => %{"dest_id" => dest_id}}, socket) do
    selected_ids = Enum.map(socket.assigns.merge_selection, & &1.id)

    socket =
      case Accounts.merge(selected_ids, dest_id) do
        {:ok, _user} ->
          put_flash(socket, :info, gettext("Successfully merged users"))

        {:error,
         %Ecto.Changeset{
           valid?: false,
           errors: [dest_id: {"can't be blank", [validation: :required]}]
         }} ->
          Logger.error("Unable to merge users #{inspect(selected_ids)}: a destination must be specified")

          put_flash(
            socket,
            :error,
            gettext("Error merging users: a destination must be specified")
          )

        {:error, reason} ->
          Logger.error("Unable to merge users #{inspect(selected_ids)} into #{dest_id}: #{inspect(reason)}")

          put_flash(socket, :error, gettext("Error merging users"))
      end

    socket =
      socket
      |> reset_current_editing()
      |> assign(merge_selection: [])
      |> push_patch(to: "/admin/users")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Accounts.get_user(id) do
      {:ok, user} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, record: user)}

          :edit ->
            changeset = change(user, %{})

            socket =
              assign(socket, record: user, changeset: changeset, action: :edit)

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this User"))
        Logger.error("Error retrieving User #{id}: #{inspect(reason)}")
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
        :ok -> put_flash(socket, :info, gettext("User deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete User"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        :ok ->
          put_flash(socket, :info, gettext("Users deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Users"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Accounts.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All users deleted successfully"))}
  end

  def handle_info({Accounts, [:user, :deleted], deleted_ids}, socket) when is_list(deleted_ids) do
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

  def handle_info({"merge-selected", selection}, socket) do
    selection =
      Enum.filter(Accounts.list(), fn user -> user.id in selection end)

    {:noreply, assign(socket, merge_selection: selection)}
  end

  def handle_info({Accounts, [:user, :deleted], deleted_count}, socket) when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/users")}
  end

  def handle_info({Accounts, [:user, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Accounts, [:user, :updated], updated_item}, socket) do
    {:ok, updated_item} = Accounts.get_user(updated_item.id)
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Accounts, [:user, :created], inserted_item}, socket) do
    _socket =
      if is_nil(Map.get(socket.assigns, :last_id)) do
        # Prepend to comply with default sorting
        {:noreply, stream_insert(socket, :items, inserted_item, at: 0)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(user, params) do
    Accounts.change_for_competition_registration(user, params)
  end

  defp delete(ids) when is_list(ids) do
    case Accounts.delete_many(ids) do
      {:ok, deleted} ->
        Logger.debug("Deleted #{deleted} entities")
        :ok

      :error ->
        Logger.error("""
        Error deleting multiple Users:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end
  end

  defp delete(id) do
    with {:ok, user} <- Accounts.get_user(id),
         {:ok, _result} <- Accounts.delete(user) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Error deleting User #{inspect(id)}: #{inspect(reason)}")
        :error
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Accounts.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Users updates: #{inspect(reason)}")
          error
      end
    end
  end

  defp load_entities(socket) do
    items = Accounts.list()

    stream(socket, :items, items)
  end

  defp reset_current_editing(socket) do
    entity = %User{}

    changeset = change(entity, %{})

    socket
    |> assign(:record, entity)
    |> assign(:changeset, changeset)
  end
end
