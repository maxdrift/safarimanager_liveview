defmodule SMWeb.Live.Admin.Categories.Index do
  @moduledoc """
  Categories live view
  """
  use SMWeb, :surface_view

  import SMWeb.Components.DateTimeString
  import SMWeb.Components.FieldsList
  import SMWeb.Components.Layout
  import SMWeb.Components.ShortUUID
  import SMWeb.Components.SMField

  alias SM.Categories
  alias SM.Categories.Category
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
        camera_types: Categories.list_camera_types()
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

  # Create/Edit dialog submit callback
  def handle_event("submit", %{"entity" => %{"_action" => "create"} = params}, socket) do
    case Categories.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/categories")

        socket = put_flash(socket, :info, gettext("Category created successfully"))
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("submit", %{"entity" => %{"_action" => "edit"} = params}, socket) do
    case Categories.update(socket.assigns.record, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/categories")

        socket = put_flash(socket, :info, ~s(#{gettext("Edited category")} "#{entity.name}"))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Categories.get(id) do
      {:ok, category} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, record: category)}

          :edit ->
            changeset = change(category, %{})

            socket =
              assign(socket, record: category, changeset: changeset, action: :edit)

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this Category"))
        Logger.error("Error retrieving Category #{id}: #{inspect(reason)}")
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
        :ok -> put_flash(socket, :info, gettext("Category deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete Category"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        :ok ->
          put_flash(socket, :info, gettext("Categories deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Categories"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Categories.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All categories deleted successfully"))}
  end

  def handle_info({Categories, [:category, :deleted], deleted_ids}, socket) when is_list(deleted_ids) do
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

  def handle_info({Categories, [:category, :deleted], deleted_count}, socket) when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/categories")}
  end

  def handle_info({Categories, [:category, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Categories, [:category, :updated], updated_item}, socket) do
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Categories, [:category, :created], inserted_item}, socket) do
    _socket =
      if is_nil(Map.get(socket.assigns, :last_id)) do
        {:noreply, stream_insert(socket, :items, inserted_item)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(category, params) do
    Categories.change(category, params)
  end

  defp delete(ids) when is_list(ids) do
    case Categories.delete_many(ids) do
      {:ok, ids} ->
        Logger.debug("Deleted #{Enum.count(ids)} entities")
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
    stream(socket, :items, Categories.list())
  end

  defp reset_current_editing(socket) do
    entity = %Category{}

    changeset = change(entity, %{})

    socket
    |> assign(:record, entity)
    |> assign(:changeset, changeset)
  end

  defp camera_type_option_label(:any), do: gettext("any")
  defp camera_type_option_label(:compact), do: gettext("compact")
  defp camera_type_option_label(:reflex), do: gettext("reflex")
end
