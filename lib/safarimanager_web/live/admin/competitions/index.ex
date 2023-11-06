defmodule SMWeb.Live.Admin.Competitions.Index do
  @moduledoc """
  Competitions live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Competitions.Competition
  alias SM.Competitions.CompetitionEvaluation
  alias SM.Evaluations
  alias SM.Organizations
  alias SM.Slides
  alias SM.Utils
  alias SMWeb.Components.Column
  alias SMWeb.Components.DateTimeString
  alias SMWeb.Components.FieldsList
  alias SMWeb.Components.FieldsListItem
  alias SMWeb.Components.Grid
  alias SMWeb.Components.Layout
  alias SMWeb.Components.ShortUUID
  alias SMWeb.Components.SMField
  alias Surface.Components.Context
  alias Surface.Components.Form
  alias Surface.Components.Form.Checkbox
  alias Surface.Components.Form.DateTimeLocalInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.NumberInput
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
      |> assign(
        action: changeset_action,
        competition_types: Competitions.list_competition_types(),
        organizations: Organizations.list(),
        evaluations: Evaluations.list()
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
      |> assign_form()

    socket = assign(socket, :changeset, changeset)
    {:noreply, socket}
  end

  # Create/Edit dialog submit callback
  def handle_event("submit", %{"entity" => %{"_action" => "create"} = params}, socket) do
    case Competitions.create(params) do
      {:ok, %Competition{}} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/competitions")

        socket = put_flash(socket, :info, gettext("Competition created successfully"))
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("submit", %{"entity" => %{"_action" => "edit"} = params}, socket) do
    case Competitions.update(socket.assigns.record, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/competitions")

        socket = put_flash(socket, :info, ~s(#{gettext("Edited competition")} "#{entity.name}"))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("erase-discarded-slides", _params, socket) do
    on_confirm = fn socket ->
      socket.assigns.record.id
      |> Slides.list_by_status(:discarded)
      |> Enum.map(& &1.id)
      |> Slides.delete_many()
      |> case do
        {:ok, deleted} ->
          Logger.info("Deleted #{deleted} discarded slides")
          put_flash(socket, :info, gettext("Deleted all discarded slides"))

        {:error, reason} ->
          Logger.error("Unable to delete discarded slides: #{inspect(reason)}")
          put_flash(socket, :error, gettext("Error deleting discarded slides"))
      end
    end

    {:noreply,
     confirm(socket, on_confirm,
       title: gettext("Erase discarded slides"),
       description: gettext("Are you sure you want to delete all discarded slides?"),
       confirm_text: gettext("Delete"),
       confirm_icon: "trash"
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Competitions.get(id) do
      {:ok, competition} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, record: competition)}

          :edit ->
            changeset = competition |> change(%{}) |> assign_form()

            socket =
              assign(socket, record: competition, changeset: changeset, action: :edit)

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this Competition"))
        Logger.error("Error retrieving Competition #{id}: #{inspect(reason)}")
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
        :ok -> put_flash(socket, :info, gettext("Competition deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete Competition"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        :ok ->
          put_flash(socket, :info, gettext("Competitions deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Competitions"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Competitions.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All competitions deleted successfully"))}
  end

  def handle_info({Competitions, [:competition, :deleted], deleted_ids}, socket) when is_list(deleted_ids) do
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

  def handle_info({Competitions, [:competition, :deleted], deleted_count}, socket) when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/competitions")}
  end

  def handle_info({Competitions, [:competition, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Competitions, [:competition, :updated], updated_item}, socket) do
    {:ok, updated_item} = Competitions.get(updated_item.id)
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Competitions, [:competition, :created], inserted_item}, socket) do
    _socket =
      if is_nil(Map.get(socket.assigns, :last_id)) do
        {:noreply, stream_insert(socket, :items, inserted_item)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(competition, params) do
    Competitions.change(competition, params)
  end

  defp delete(ids) when is_list(ids) do
    case Competitions.delete_many(ids) do
      {:ok, deleted} ->
        Logger.debug("Deleted #{deleted} entities")
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
    items = Competitions.list()

    stream(socket, :items, items)
  end

  defp reset_current_editing(socket) do
    entity = %Competition{}
    changeset = entity |> change(%{}) |> assign_form()

    socket
    |> assign(:record, entity)
    |> assign(:changeset, changeset)
  end

  defp assign_form(%Ecto.Changeset{} = changeset) do
    if Ecto.Changeset.get_field(changeset, :competitions_evaluations) == [] do
      all_evaluation_ids = Enum.map(Evaluations.list(), &%CompetitionEvaluation{evaluation_id: &1.id})

      changeset |> Ecto.Changeset.put_change(:competitions_evaluations, all_evaluation_ids) |> to_form()
    else
      to_form(changeset)
    end
  end

  defp slide_status_to_label(:submitted_jury), do: gettext("submitted_jury")
  defp slide_status_to_label(:submitted_fixed), do: gettext("submitted_fixed")
  defp slide_status_to_label(:discarded), do: gettext("discarded")
  defp slide_status_to_label(status), do: status
end
