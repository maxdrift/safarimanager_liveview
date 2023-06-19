defmodule SMWeb.Live.Admin.Subjects.Index do
  @moduledoc """
  Subjects live view
  """
  use SMWeb, :surface_view

  alias SM.Subjects
  alias SM.Subjects.Subject
  alias SMWeb.Components.Column
  alias SMWeb.Components.Grid
  alias SMWeb.Components.Layout
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.NumberInput
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput
  alias Surface.Components.LivePatch

  require Logger

  @page_size 50

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = subscribe(socket)

    changeset_action =
      case socket.assigns.live_action do
        :new -> :create
        :edit -> :edit
        _index -> nil
      end

    socket =
      socket
      |> load_entities()
      |> reset_current_editing()
      # TODO: Maybe use preload here
      |> assign(
        action: changeset_action,
        subject_types: Subjects.list_subject_types(),
        coefficients: Subjects.list_subject_coefficients()
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
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
    case Subjects.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/subjects")

        socket = put_flash(socket, :info, gettext("Subject created successfully"))
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
    case Subjects.update(socket.assigns.editing_entity, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/subjects")

        socket = put_flash(socket, :info, ~s(#{gettext("Edited subject")} "#{entity.name}"))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("load_more", %{}, socket) do
    last_id = socket.assigns.last_id

    items =
      if is_nil(last_id) do
        []
      else
        [after: last_id, cursor_field: :numeric_id, max_rows: @page_size]
        |> Subjects.stream()
        |> Stream.take(@page_size)
      end

    last_id = last_entity_id(items, id_field: :numeric_id)

    socket =
      items
      |> Enum.reduce(socket, fn item, socket ->
        stream_insert(socket, :items, item)
      end)
      |> assign(:last_id, last_id)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Subjects.get(id) do
      {:ok, subject} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, editing_entity: subject)}

          :edit ->
            changeset = change(subject, %{})

            socket =
              socket
              |> assign(
                editing_entity: subject,
                editing_changeset: changeset,
                action: :edit
              )

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this Subject"))
        Logger.error("Error retrieving Subject #{id}: #{inspect(reason)}")
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
        :ok -> put_flash(socket, :info, gettext("Subject deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete Subject"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        :ok ->
          put_flash(socket, :info, gettext("Subjects deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Subjects"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Subjects.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All subjects deleted successfully"))}
  end

  def handle_info({Subjects, [:subject, :deleted], deleted_ids}, socket)
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

  def handle_info({Subjects, [:subject, :deleted], deleted_count}, socket)
      when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/subjects")}
  end

  def handle_info({Subjects, [:subject, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Subjects, [:subject, :updated], updated_item}, socket) do
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Subjects, [:subject, :created], inserted_item}, socket) do
    _socket =
      if is_nil(socket.assigns.last_id) do
        {:noreply, stream_insert(socket, :items, inserted_item)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(subject, params) do
    Subjects.change(subject, params)
  end

  defp delete(ids) when is_list(ids) do
    case Subjects.delete_many(ids) do
      {:ok, ids} ->
        Logger.debug("Deleted #{Enum.count(ids)} entities")
        :ok

      :error ->
        Logger.error("""
        Error deleting multiple Subjects:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end
  end

  defp delete(id) do
    with {:ok, subject} <- Subjects.get(id),
         {:ok, _result} <- Subjects.delete(subject) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Error deleting Subject #{inspect(id)}: #{inspect(reason)}")
        :error
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Subjects.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Subjects updates: #{inspect(reason)}")
          error
      end
    end
  end

  defp load_entities(socket) do
    items =
      [cursor_field: :numeric_id, max_rows: @page_size]
      |> Subjects.stream()
      |> Stream.take(@page_size)

    last_id = last_entity_id(items, id_field: :numeric_id)

    socket
    |> assign(:last_id, last_id)
    |> stream(:items, items)
  end

  defp reset_current_editing(socket) do
    entity = %Subject{}

    changeset = change(entity, %{})

    socket
    |> assign(:editing_entity, entity)
    |> assign(:editing_changeset, changeset)
  end

  defp last_entity_id(items, opts) do
    id_field = Keyword.get(opts, :id_field, :id)

    case Enum.reverse(items) do
      [] -> nil
      [last | _rest] -> Map.get(last, id_field)
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
