defmodule SMWeb.Components.Admin.Competitions do
  @moduledoc """
  Competitions live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Competitions.Competition
  alias SM.Evaluations
  alias SM.Organizations
  alias SMWeb.Components.Admin.Competitions.Edit
  alias SMWeb.Components.Admin.Competitions.List
  alias SMWeb.Components.Admin.Competitions.Show
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
      |> assign(:organizations, Organizations.list())

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
        :ok -> put_flash(socket, :info, "Competition deleted successfully")
        :error -> put_flash(socket, :error, "Unable to delete Competition")
      end

    ConfirmationDialog.hide("delete-confirmation")
    {:noreply, socket}
  end

  def handle_event("confirm", %{}, %{assigns: %{to_be_deleted: [_ | _] = ids}} = socket) do
    socket =
      case delete(ids) do
        :ok -> put_flash(socket, :info, "Competitions deleted successfully")
        :error -> put_flash(socket, :error, "Unable to delete Competitions")
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
    case Competitions.create(params) do
      {:ok, %Competition{id: competition_id}} ->
        # TODO: Perform evaluations selection in the UI
        all_evaluations = Evaluations.list() |> Enum.map(& &1.id)

        {:ok, _competition} =
          Competitions.update_allowed_evaluations(competition_id, all_evaluations)

        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/competitions")

        Edit.hide("edit-dialog")
        socket = put_flash(socket, :info, "Competition created successfully")
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
    case Competitions.update(socket.assigns.editing_entity, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/competitions")

        Edit.hide("edit-dialog")

        socket = put_flash(socket, :info, ~s(Edited competition "#{entity.name}"))

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
      {:ok, competition} ->
        changeset = change(competition, %{})

        Edit.show("edit-dialog", :edit)

        socket =
          socket
          |> assign(:editing_entity, competition)
          |> assign(:editing_changeset, changeset)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error showing Edit modal: #{inspect(reason)}")
        socket = put_flash(socket, :error, "Unable to edit this Competition")
        {:noreply, socket}
    end
  end

  def handle_params(%{"id" => id, "action" => "show"}, _url, socket) do
    case get(id) do
      {:ok, competition} ->
        Show.show("show-dialog", competition)

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Unable to show this Competition")
        Logger.error("Error showing Competition: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Competitions, [:competition, _action], _result}, socket) do
    socket =
      socket
      |> load_entities()
      |> reset_selection()

    {:noreply, socket}
  end

  # Internal

  defp list do
    Competitions.list()
  end

  defp get(id) do
    Competitions.get(id)
  end

  defp new do
    %Competition{}
  end

  defp change(competition, params) do
    Competitions.change(competition, params)
  end

  defp delete(ids) when is_list(ids) do
    case Competitions.delete_many(ids) do
      {:ok, deleted} ->
        IO.puts("Deleted #{deleted} entities")
        :ok

      :error ->
        Logger.error("""
        Error deleting multiple Competitions:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end
  end

  defp delete(id) do
    with {:ok, competition} <- Competitions.get(id),
         {:ok, _result} <- Competitions.delete(competition) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Error deleting Competition #{inspect(id)}: #{inspect(reason)}")
        :error
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Competitions.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Competitions updates: #{inspect(reason)}")
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
