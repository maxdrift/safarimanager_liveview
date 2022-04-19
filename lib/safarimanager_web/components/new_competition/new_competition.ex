defmodule SMWeb.NewCompetition do
  @moduledoc """
  NewCompetition live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Competitions.Competition

  alias SMWeb.Components.Competitions.Form
  alias SMWeb.Components.FormActions

  require Logger

  data action, :atom, values!: [:create, :edit], default: :create

  data entity, :struct, default: %Competition{}
  data changeset, :changeset
  data validate, :event, default: "validate"
  data submit, :event, default: "submit"
  data redirect_to, :string
  data entity_name, :string
  data competitions, :list, default: []

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:changeset, Competitions.change(%Competition{}))
      |> assign(:competitions, Competitions.list())

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
        socket =
          socket
          |> assign(:entity, %Competition{})
          |> assign(:changeset, Competitions.change(socket.assigns.entity))
          |> push_redirect(to: "/organize/#{competition_id}/participants")

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
    socket = push_redirect(socket, to: "/organize/#{competition_id}/participants")

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
