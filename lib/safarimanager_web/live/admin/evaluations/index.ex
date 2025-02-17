defmodule SMWeb.Live.Admin.Evaluations.Index do
  @moduledoc """
  Evaluations live view
  """
  use SMWeb, :live_view

  import SMWeb.Components.DateTimeString
  import SMWeb.Components.FieldsList
  import SMWeb.Components.Layout
  import SMWeb.Components.ShortUUID

  alias SM.Evaluations
  alias SM.Evaluations.Evaluation

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
        evaluation_types: Evaluations.list_evaluation_types()
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
    case Evaluations.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/evaluations")

        socket = put_flash(socket, :info, gettext("Evaluation created successfully"))
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :entity))}
    end
  end

  def handle_event("submit", %{"_action" => "edit", "entity" => params}, socket) do
    case Evaluations.update(socket.assigns.record, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/evaluations")

        socket =
          put_flash(
            socket,
            :info,
            ~s(#{gettext("Edited evaluation")} "#{entity.name}")
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :entity))}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Evaluations.get(id) do
      {:ok, evaluation} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, record: evaluation)}

          :edit ->
            changeset = change(evaluation, %{})

            socket =
              assign(socket, record: evaluation, form: to_form(changeset, as: :entity), action: :edit)

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this Evaluation"))

        Logger.error("Error retrieving Evaluation #{id}: #{inspect(reason)}")
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
        :ok -> put_flash(socket, :info, gettext("Evaluation deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete Evaluation"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        :ok ->
          put_flash(socket, :info, gettext("Evaluations deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Evaluations"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Evaluations.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All evaluations deleted successfully"))}
  end

  def handle_info({Evaluations, [:evaluation, :deleted], deleted_ids}, socket) when is_list(deleted_ids) do
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

  def handle_info({Evaluations, [:evaluation, :deleted], deleted_count}, socket) when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/evaluations")}
  end

  def handle_info({Evaluations, [:evaluation, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Evaluations, [:evaluation, :updated], updated_item}, socket) do
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Evaluations, [:evaluation, :created], inserted_item}, socket) do
    _socket =
      if is_nil(Map.get(socket.assigns, :last_id)) do
        {:noreply, stream_insert(socket, :items, inserted_item)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(evaluation, params) do
    Evaluations.change(evaluation, params)
  end

  defp delete(ids) when is_list(ids) do
    case Evaluations.delete_many(ids) do
      {:ok, deleted} ->
        Logger.debug("Deleted #{deleted} entities")
        :ok

      :error ->
        Logger.error("""
        Error deleting multiple Evaluations:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end
  end

  defp delete(id) do
    with {:ok, evaluation} <- Evaluations.get(id),
         {:ok, _result} <- Evaluations.delete(evaluation) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Error deleting Evaluation #{inspect(id)}: #{inspect(reason)}")
        :error
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Evaluations.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Evaluations updates: #{inspect(reason)}")
          error
      end
    end
  end

  defp load_entities(socket) do
    items = Evaluations.list()

    stream(socket, :items, items)
  end

  defp reset_current_editing(socket) do
    entity = %Evaluation{}

    changeset = change(entity, %{})

    socket
    |> assign(:record, entity)
    |> assign(:form, to_form(changeset, as: :entity))
  end
end
