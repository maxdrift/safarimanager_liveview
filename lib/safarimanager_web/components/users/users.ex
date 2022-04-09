defmodule SMWeb.Users do
  @moduledoc """
  Users live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Accounts.User

  alias SMWeb.Atoms.Alert
  alias SMWeb.Components.ConfirmationDialog
  alias SMWeb.Components.Users.Edit
  alias SMWeb.Components.Users.List
  alias SMWeb.Components.Users.Show
  alias Surface.Components.LivePatch

  require Logger

  # Alert duration in milliseconds
  @alert_duration 15_000

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = subscribe(socket)

    socket =
      socket
      |> load_entities()
      |> reset_alert()
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
        :ok -> set_alert(socket, "info", "User deleted successfully", @alert_duration)
        :error -> set_alert(socket, "error", "Unable to delete User", @alert_duration)
      end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [_ | _] = ids}} = socket) do
    socket =
      case delete(ids) do
        :ok -> set_alert(socket, "info", "Users deleted successfully", @alert_duration)
        :error -> set_alert(socket, "error", "Unable to delete Users", @alert_duration)
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
    case Accounts.register_simplified_user(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          # Note: remember events pushed from the server via push_event are global
          # and will be dispatched to all active hooks on the client who are handling that event.
          |> push_event("reset_entity_organization_id", %{})
          |> push_patch(to: "/admin/users")

        Edit.hide("edit-dialog")
        socket = set_alert(socket, "info", "User created successfully", @alert_duration)
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
    case Accounts.update(socket.assigns.editing_entity, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          # Note: remember events pushed from the server via push_event are global
          # and will be dispatched to all active hooks on the client who are handling that event.
          |> push_event("reset_entity_organization_id", %{})
          |> push_patch(to: "/admin/users")

        Edit.hide("edit-dialog")

        socket =
          set_alert(
            socket,
            "info",
            ~s(Edited user "#{entity.first_name} #{entity.last_name}"),
            @alert_duration
          )

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
      {:ok, user} ->
        changeset = change(user, %{})
        Edit.show("edit-dialog", :edit)

        socket =
          socket
          |> assign(:editing_entity, user)
          |> assign(:editing_changeset, changeset)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error showing Edit modal: #{inspect(reason)}")
        socket = set_alert(socket, "error", "Unable to edit this User", @alert_duration)
        {:noreply, socket}
    end
  end

  def handle_params(%{"id" => id, "action" => "show"}, _url, socket) do
    case get(id) do
      {:ok, user} ->
        Show.show("show-dialog", user)

        {:noreply, socket}

      {:error, reason} ->
        socket = set_alert(socket, "error", "Unable to show this User", @alert_duration)
        Logger.error("Error showing User: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Accounts, [:user, _action], _result}, socket) do
    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:noreply, socket}
  end

  def handle_info(:remove_alert, socket) do
    socket = reset_alert(socket)

    {:noreply, socket}
  end

  # Internal

  defp list do
    Accounts.list()
  end

  defp get(id) do
    Accounts.get_user(id)
  end

  defp new do
    %User{}
  end

  defp change(user, params) do
    Accounts.change_for_competition_registration(user, params)
  end

  defp delete(ids) when is_list(ids) do
    case Accounts.delete_many(ids) do
      {:ok, deleted} ->
        IO.puts("Deleted #{deleted} entities")
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
    items =
      Enum.map(list(), fn item ->
        Map.put(item, :selected?, false)
      end)

    assign(socket, :items, items)
  end

  defp set_alert(socket, level, message) do
    socket
    |> assign(:error_level, level)
    |> assign(:error_message, message)
  end

  defp set_alert(socket, level, message, remove_after) when is_integer(remove_after) do
    socket = set_alert(socket, level, message)
    {:ok, _tref} = :timer.send_after(remove_after, :remove_alert)

    socket
  end

  defp reset_alert(socket) do
    socket
    |> assign(:error_level, "info")
    |> assign(:error_message, nil)
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
