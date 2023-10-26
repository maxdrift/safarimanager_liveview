defmodule SMWeb.Live.NewCompetition do
  @moduledoc """
  New Competition live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Competitions.Competition
  alias SM.Competitions.CompetitionEvaluation
  alias SM.Evaluations
  alias SM.Organizations
  alias SMWeb.Components.FormActions
  alias SMWeb.Components.Layout
  alias SMWeb.Live.Admin.Competitions.Form, as: CompetitionForm
  alias Surface.Components.Form
  alias Surface.Components.Form.Checkbox
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.TextInput

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = if connected?(socket), do: Competitions.subscribe()

    socket =
      assign(socket,
        entity: %Competition{},
        changeset: Competitions.change(%Competition{}),
        competitions: Competitions.list(),
        organizations: Organizations.list(),
        evaluations: Evaluations.list(),
        competition_types: Competitions.list_competition_types(),
        duplication_form: to_form(%{}, as: :duplicate_competition)
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"entity" => entity}, socket) do
    changeset =
      socket.assigns.entity
      |> Competitions.change(entity)
      |> Map.put(:action, :validate)
      |> assign_form()

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("submit", %{"entity" => entity}, socket) do
    case Competitions.create(entity) do
      {:ok, %Competition{id: competition_id}} ->
        socket =
          socket
          |> assign(:entity, %Competition{})
          |> assign(:changeset, Competitions.change(socket.assigns.entity))
          |> put_flash(:info, gettext("Competition created successfully"))
          |> push_navigate(to: "/organize/#{competition_id}/participants")

        {:noreply, socket}

      {:error, changeset} ->
        Logger.error("Unable to create competition '#{entity["name"]}': #{inspect(changeset)}")

        socket =
          socket
          |> put_flash(:error, gettext("Unable to create competition"))
          |> assign(changeset: changeset)

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

  def handle_event("duplication-config", %{"competition_id" => competition_id}, socket) do
    {:ok, competition} = Competitions.get(competition_id)

    form =
      to_form(
        %{
          "competition_id" => competition.id,
          "new_competition_name" => competition.name,
          "new_for_teams" => (competition.for_teams && "true") || "false",
          "for_teams" => (competition.for_teams && "true") || "false",
          "participants" => "false",
          "teams" => "false",
          "jurors" => "false",
          "slides" => "false",
          "selection" => "false",
          "votes" => "false"
        },
        as: :duplicate_competition
      )

    socket = assign(socket, duplication_form: form)

    {:noreply, socket}
  end

  def handle_event("reset-duplication-config", _params, socket) do
    form =
      to_form(
        %{
          "competition_id" => nil,
          "new_competition_name" => "",
          "new_for_teams" => "false",
          "for_teams" => "false",
          "participants" => "false",
          "teams" => "false",
          "jurors" => "false",
          "slides" => "false",
          "selection" => "false",
          "votes" => "false"
        },
        as: :duplicate_competition
      )

    socket = assign(socket, duplication_form: form)

    {:noreply, socket}
  end

  def handle_event("validate-duplicate", %{"duplicate_competition" => %{"competition_id" => ""}}, socket) do
    {:noreply, socket}
  end

  def handle_event("validate-duplicate", %{"duplicate_competition" => params}, socket) do
    form =
      params
      |> validate_duplication_params()
      |> to_form(as: :duplicate_competition)

    socket = assign(socket, :duplication_form, form)

    {:noreply, socket}
  end

  def handle_event("submit-duplicate", %{"duplicate_competition" => params}, socket) do
    case Competitions.duplicate(params["competition_id"], params) do
      {:ok, _new_competition} ->
        {:noreply, put_flash(socket, :info, gettext("Successfully duplicated competition"))}

      {:error, changeset} ->
        Ecto.Changeset.traverse_errors(changeset, fn _changeset, field, {error, _opts} ->
          Logger.error("#{field} #{error}")
        end)

        {:noreply, put_flash(socket, :error, gettext("Error duplicating competition"))}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    socket =
      assign(socket,
        changeset: %Competition{} |> Competitions.change() |> assign_form(),
        competitions: Competitions.list(),
        organizations: Organizations.list()
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Competitions, [:competition, _], _inserted_item}, socket) do
    socket = assign(socket, competitions: Competitions.list())
    {:noreply, socket}
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp value_or_na(nil), do: "N/A"
  defp value_or_na(value), do: value

  defp format_date(nil), do: "N/A"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end

  defp validate_duplication_params(params) do
    teams = if params["participants"] == "true" and params["for_teams"] == "true", do: params["teams"], else: "false"
    slides = if params["participants"] == "true", do: params["slides"], else: "false"
    selection = if slides == "true", do: params["selection"], else: "false"
    votes = if selection == "true", do: params["votes"], else: "false"

    %{
      "competition_id" => params["competition_id"],
      "new_competition_name" => params["new_competition_name"],
      "new_for_teams" => params["new_for_teams"],
      "for_teams" => params["for_teams"],
      "participants" => params["participants"],
      "teams" => teams,
      "jurors" => params["jurors"],
      "slides" => slides,
      "selection" => selection,
      "votes" => votes
    }
  end

  defp assign_form(%Ecto.Changeset{} = changeset) do
    if Ecto.Changeset.get_field(changeset, :competitions_evaluations) == [] do
      all_evaluation_ids = Enum.map(Evaluations.list(), &%CompetitionEvaluation{evaluation_id: &1.id})

      changeset |> Ecto.Changeset.put_change(:competitions_evaluations, all_evaluation_ids) |> to_form()
    else
      to_form(changeset)
    end
  end
end
