defmodule SMWeb.NewCompetition do
  @moduledoc """
  NewCompetition live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Competitions.Competition

  alias SMWeb.Components.Competitions.Form
  alias SMWeb.Components.Competitions.FormActions

  require Logger

  data action, :atom, values!: [:create, :edit], default: :create

  data entity, :struct, default: %Competition{}
  data changeset, :changeset
  data validate, :event, default: "validate"
  data submit, :event, default: "submit"
  data redirect_to, :string
  data entity_name, :string

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    changeset = Ecto.Changeset.change(%Competition{})

    {:ok, assign(socket, :changeset, changeset)}
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

  # def handle_event(event_name, params, socket) do
  #   IO.inspect(event_name)
  #   IO.inspect(params)

  #   {:noreply, socket}
  # end
end
