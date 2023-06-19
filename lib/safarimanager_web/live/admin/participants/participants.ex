defmodule SMWeb.Live.Admin.Participants do
  @moduledoc """
  Participants live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Categories
  alias SM.Competitions
  alias SM.Participants
  alias SM.Participants.Participant
  alias SMWeb.Live.Admin.Participants.Edit
  alias SMWeb.Live.Admin.Participants.List
  alias SMWeb.Live.Admin.Participants.Show
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
      |> assign(:users, Accounts.list())
      |> assign(:categories, Categories.list())
      |> assign(:competitions, Competitions.list())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "toggle-select-item",
        %{
          "user-id" => user_id,
          "competition-id" => competition_id,
          "selected" => selected?
        },
        socket
      ) do
    items =
      Enum.map(socket.assigns.items, fn
        %_struct{user_id: ^user_id, competition_id: ^competition_id} = item ->
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

  def handle_event(
        "delete-one",
        %{"user-id" => user_id, "competition-id" => competition_id},
        socket
      ) do
    ConfirmationDialog.show("delete-confirmation")
    {:noreply, assign(socket, :to_be_deleted, [{user_id, competition_id}])}
  end

  def handle_event("delete-many", %{}, socket) do
    ConfirmationDialog.show("delete-confirmation")
    {:noreply, assign(socket, :to_be_deleted, socket.assigns.selected)}
  end

  def handle_event(
        "confirm",
        %{},
        %{assigns: %{to_be_deleted: [{user_id, competition_id}]}} = socket
      ) do
    socket =
      case delete(user_id, competition_id) do
        {:ok, _result} ->
          put_flash(socket, :info, "Participant deleted successfully")

        {:error, reason} ->
          Logger.error("Error deleting Participant: #{inspect(reason)}")

          put_flash(socket, :error, "Unable to delete Participant")
      end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [_ | _] = ids}} = socket) do
    socket =
      case delete(ids) do
        {:ok, count} ->
          put_flash(socket, :info, "#{count} participant(s) deleted successfully")

        {:error, reason} ->
          Logger.error("Error deleting Participants: #{inspect(reason)}")

          put_flash(socket, :error, "Unable to delete Participants")
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
    case Participants.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/participants")

        Edit.hide("edit-dialog")
        socket = put_flash(socket, :info, "Participant created successfully")
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
    case Participants.update(socket.assigns.editing_entity, params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/participants")

        Edit.hide("edit-dialog")

        socket = put_flash(socket, :info, ~s(Edited participant))

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

  def handle_params(
        %{"user_id" => user_id, "competition_id" => competition_id, "action" => "edit"},
        _url,
        socket
      ) do
    case get(user_id, competition_id) do
      {:ok, participant} ->
        changeset = change(participant, %{})
        Edit.show("edit-dialog", :edit)

        socket =
          socket
          |> assign(:editing_entity, participant)
          |> assign(:editing_changeset, changeset)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error showing Edit modal: #{inspect(reason)}")
        socket = put_flash(socket, :error, "Unable to edit this Participant")
        {:noreply, socket}
    end
  end

  def handle_params(
        %{"user_id" => user_id, "competition_id" => competition_id, "action" => "show"},
        _url,
        socket
      ) do
    case get(user_id, competition_id) do
      {:ok, participant} ->
        Show.show("show-dialog", participant)

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Unable to show this Participant")
        Logger.error("Error showing Participant: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Participants, [:participant, _action], _result}, socket) do
    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:noreply, socket}
  end

  def handle_info({Participants, [:competition, _action], _result}, socket) do
    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:noreply, socket}
  end

  def handle_info({Participants, [:user, _action], _result}, socket) do
    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:noreply, socket}
  end

  # Internal

  defp list do
    Participants.list()
  end

  defp get(user_id, competition_id) do
    Participants.get(user_id, competition_id)
  end

  defp new do
    %Participant{}
  end

  defp change(participant, params) do
    Participants.change(participant, params)
  end

  defp delete(ids) when is_list(ids) do
    Enum.reduce_while(ids, {:ok, 0}, fn {user_id, competition_id}, acc ->
      case delete(user_id, competition_id) do
        {:ok, _result} -> {:cont, acc + 1}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp delete(user_id, competition_id) do
    Participants.delete(user_id, competition_id)
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Participants.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Participants updates: #{inspect(reason)}")
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
      |> Enum.map(&{&1.user_id, &1.competition_id})

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
