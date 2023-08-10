defmodule SMWeb.Live.NewCompetition do
  @moduledoc """
  New Competition live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Competitions.Competition
  alias SM.Evaluations
  alias SM.Organizations
  alias SMWeb.Components.FormActions
  alias SMWeb.Components.Layout
  alias SMWeb.Live.Admin.Competitions.Form

  require Logger

  data action, :atom, values!: [:create, :edit], default: :create
  data competition_types, :list, default: Competitions.list_competition_types()
  data entity, :struct, default: %Competition{}
  data changeset, :changeset
  data validate, :event, default: "validate"
  data submit, :event, default: "submit"
  data redirect_to, :string
  data entity_name, :string
  data competitions, :list, default: []

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:changeset, Competitions.change(%Competition{}))
      |> assign(:competitions, Competitions.list())
      |> assign(:organizations, Organizations.list())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"entity" => entity}, socket) do
    changeset =
      socket.assigns.entity
      |> Competitions.change(entity)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("submit", %{"entity" => entity}, socket) do
    case Competitions.create(entity) do
      {:ok, %Competition{id: competition_id}} ->
        # TODO: Perform evaluations selection in the UI
        all_evaluations = Enum.map(Evaluations.list(), & &1.id)

        {:ok, _competition} =
          Competitions.update_allowed_evaluations(competition_id, all_evaluations)

        socket =
          socket
          |> assign(:entity, %Competition{})
          |> assign(:changeset, Competitions.change(socket.assigns.entity))
          |> push_navigate(to: "/organize/#{competition_id}/participants")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("reset", %{}, socket) do
    socket =
      socket
      |> assign(:entity, %Competition{})
      |> assign(:changeset, Competitions.change(socket.assigns.entity))

    {:noreply, socket}
  end

  def handle_event("open", %{"id" => competition_id}, socket) do
    socket = push_navigate(socket, to: "/organize/#{competition_id}/participants")

    {:noreply, socket}
  end

  # def handle_event(event_name, params, socket) do
  #   IO.inspect(event_name)
  #   IO.inspect(params)

  #   {:noreply, socket}
  # end

  defp value_or_na(nil), do: "N/A"
  defp value_or_na(value), do: value

  defp format_date(nil), do: "N/A"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
