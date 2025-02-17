defmodule SMWeb.Live.Admin.Participants.Index do
  @moduledoc """
  Participants live view
  """
  use SMWeb, :live_view

  import SMWeb.Components.Column
  import SMWeb.Components.DateTimeString
  import SMWeb.Components.FieldsList
  import SMWeb.Components.Layout
  import SMWeb.Components.SMField

  alias SM.Accounts
  alias SM.Categories
  alias SM.Competitions
  alias SM.Participants
  alias SM.Participants.Participant

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = subscribe(socket)

    changeset_action = SMWeb.live_action_to_changeset_action(socket.assigns.live_action)

    socket =
      socket
      |> stream_configure(:items, dom_id: &"items-#{&1.user_id}-#{&1.competition_id}")
      |> load_entities()
      |> reset_current_editing()
      |> assign(
        action: changeset_action,
        users: Accounts.list(),
        categories: Categories.list(),
        competitions: Competitions.list()
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  # Create/Edit dialog validate callback
  def handle_event("validate", %{"entity" => params}, socket) do
    form =
      socket.assigns.record
      |> change(params)
      |> to_form(action: :validate, as: :entity)

    socket = assign(socket, :form, form)
    {:noreply, socket}
  end

  # Create/Edit dialog submit callback
  def handle_event("submit", %{"_action" => "create", "entity" => params}, socket) do
    case Participants.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/participants")

        socket = put_flash(socket, :info, gettext("Participant created successfully"))
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :entity))}
    end
  end

  def handle_event("submit", %{"_action" => "edit", "entity" => params}, socket) do
    case Participants.update(socket.assigns.record, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/participants")

        socket =
          put_flash(
            socket,
            :info,
            ~s(#{gettext("Edited participant")} "#{entity.user.last_name} #{entity.user.first_name}")
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :entity))}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"user_id" => user_id, "competition_id" => competition_id}, _url, socket) do
    case Participants.get(user_id, competition_id) do
      {:ok, participant} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, record: participant)}

          :edit ->
            changeset = change(participant, %{})

            socket =
              assign(socket, record: participant, form: to_form(changeset, as: :entity), action: :edit)

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this Participant"))

        Logger.error("Error retrieving Participant #{user_id}/#{competition_id}: #{inspect(reason)}")

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
        :ok -> put_flash(socket, :info, gettext("Participant deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete Participant"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        {:ok, _count} ->
          put_flash(socket, :info, gettext("Participants deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Participants"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Participants.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All participants deleted successfully"))}
  end

  def handle_info({Participants, [:participant, :deleted], deleted_ids}, socket) when is_list(deleted_ids) do
    socket =
      deleted_ids
      |> Stream.map(fn {user_id, competition_id} -> "items-#{user_id}-#{competition_id}" end)
      |> Stream.scan(socket, fn dom_id, socket ->
        stream_delete_by_dom_id(socket, :items, dom_id)
      end)
      |> Enum.reverse()
      |> hd()

    {:noreply, socket}
  end

  def handle_info({Participants, [:participant, :deleted], deleted_count}, socket) when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/participants")}
  end

  def handle_info({Participants, [:participant, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Participants, [:participant, :updated], updated_item}, socket) do
    {:ok, updated_item} = Participants.get(updated_item.user_id, updated_item.competition_id)
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Participants, [:participant, :created], inserted_item}, socket) do
    _socket =
      if is_nil(Map.get(socket.assigns, :last_id)) do
        {:noreply, stream_insert(socket, :items, inserted_item)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(participant, params) do
    Participants.change(participant, params)
  end

  defp delete(ids) when is_list(ids) do
    Enum.reduce_while(ids, {:ok, 0}, fn {user_id, competition_id}, {:ok, acc} ->
      case delete(user_id, competition_id) do
        {:ok, _result} -> {:cont, {:ok, acc + 1}}
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
    items = Participants.list()

    stream(socket, :items, items)
  end

  defp reset_current_editing(socket) do
    entity = %Participant{}

    changeset = change(entity, %{})

    socket
    |> assign(:record, entity)
    |> assign(:form, to_form(changeset, as: :entity))
  end
end
