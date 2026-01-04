defmodule SMWeb.Live.Admin.Competitions.Form do
  @moduledoc """
  Competitions form component.
  """
  use SMWeb, :live_component
  use Gettext, backend: SMWeb.Gettext

  alias SM.Competitions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- <h2 class="text-2xl font-semibold text-gray-800 dark:text-gray-100 mb-6">{@title}</h2> --%>

      <.form
        for={@form}
        id="competition-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <div class="flex flex-wrap pt-3">
          <.input
            id="competition-name-input"
            field={@form[:name]}
            type="text"
            label={gettext("Name")}
            required
            class="form-control w-full px-3"
          />
          <.input
            id="competition-organization-input"
            field={@form[:organization_id]}
            type="select"
            options={Enum.map(@organizations, &{&1.name, &1.id})}
            label={gettext("Organization")}
            class="form-control w-full px-3"
          />
          <.input
            id="competition-for-teams-input"
            field={@form[:for_teams]}
            type="checkbox"
            label={gettext("For teams")}
            class="form-control w-1/2 px-3"
          />
          <.input
            id="competition-type-input"
            field={@form[:type]}
            type="select"
            options={
              Enum.map(@competition_types, fn {value, label} ->
                {String.capitalize(Gettext.gettext(SMWeb.Gettext, label)), value}
              end)
            }
            label={gettext("Type")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={@form[:start_time]}
            type="datetime-local"
            label={gettext("Start date/time")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={@form[:end_time]}
            type="datetime-local"
            label={gettext("End date/time")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={@form[:street_name]}
            type="text"
            label={gettext("Street name")}
            class="form-control w-4/5 px-3"
          />
          <.input
            field={@form[:street_number]}
            type="text"
            label={gettext("Number")}
            class="form-control w-1/5 px-3"
          />
          <.input
            field={@form[:postal_code]}
            type="text"
            label={gettext("Postal code")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={@form[:city]}
            type="text"
            label={gettext("City")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={@form[:state]}
            type="text"
            label={gettext("State/Province")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={@form[:country]}
            type="text"
            label={gettext("Country")}
            class="form-control w-1/2 px-3"
          />
        </div>

        <div class="text-lg w-full px-3">{gettext("Allowed evaluations")}:</div>
        <div id="allowed-evaluations-inputs" class="flex flex-col w-full px-3">
          <.inputs_for :let={evaluation} field={@form[:competitions_evaluations]}>
            <div class="flex flex-row items-center gap-1 my-1">
              <.hidden_input name="entity[evaluation_sort][]" value={evaluation.index} />
              <.input
                field={evaluation[:evaluation_id]}
                type="select"
                options={Enum.map(@evaluations, &{&1.name, &1.id})}
                label={gettext("Evaluation")}
                class="form-control"
              />
              <label class="btn btn-ghost btn-square btn-sm">
                <input
                  type="checkbox"
                  name="entity[evaluation_drop][]"
                  value={evaluation.index}
                  class="hidden"
                />
                <.icon name="hero-trash" class="w-4 h-4" />
              </label>
            </div>
          </.inputs_for>
        </div>

        <div class="form-control w-full px-3">
          <label class="btn btn-ghost btn-sm">
            <input type="checkbox" name="entity[evaluation_sort][]" class="hidden" />
            <.icon name="hero-plus-circle" class="w-6 h-6" /> {gettext("add more")}
          </label>
        </div>

        <div class="text-lg w-full px-3">{gettext("Settings")}:</div>
        <.inputs_for :let={settings} field={@form[:settings]}>
          <.input
            field={settings[:number_of_jurors]}
            type="number"
            label={gettext("Number of jurors")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:evaluations_per_juror]}
            type="number"
            label={gettext("Evaluations per juror")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:max_jury_slides]}
            type="number"
            label={gettext("Max slides for jury")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:max_submitted_slides]}
            type="number"
            label={gettext("Max submitted slides")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:proportional_submission]}
            type="checkbox"
            label={gettext("Proportional submission")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:submission_ratio]}
            type="number"
            step="0.01"
            label={gettext("Submission ratio")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:fixed_points_multiplier]}
            type="number"
            step="0.01"
            label={gettext("Fixed points multiplier")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:penalty_amount]}
            type="number"
            step="0.01"
            label={gettext("Penalty amount")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:coefficient_mode]}
            type="select"
            options={
              Enum.map(@coefficient_modes, fn {value, label} ->
                {String.capitalize(Gettext.gettext(SMWeb.Gettext, label)), value}
              end)
            }
            label={gettext("Coefficient mode")}
            class="form-control w-1/2 px-3"
          />
          <.input
            field={settings[:dynamic_coefficient_mode]}
            type="select"
            options={
              Enum.map(@dynamic_coefficient_modes, fn {value, label} ->
                {String.capitalize(Gettext.gettext(SMWeb.Gettext, label)), value}
              end)
            }
            label={gettext("Dynamic coefficient mode")}
            class="form-control w-1/2 px-3"
          />

          <div class="text-lg w-full px-3">{gettext("Dynamic coefficients")}:</div>
          <.inputs_for :let={dynamic_coefficient} field={settings[:dynamic_coefficients]}>
            <.input
              field={dynamic_coefficient[:name]}
              type="text"
              label={gettext("Name")}
              class="form-control w-1/2 px-3"
            />
            <.input
              field={dynamic_coefficient[:value]}
              type="number"
              step="0.01"
              label={gettext("Value")}
              class="form-control w-1/2 px-3"
            />
            <.input
              field={dynamic_coefficient[:from]}
              type="number"
              step="0.01"
              label={gettext("From")}
              class="form-control w-1/2 px-3"
            />
            <.input
              field={dynamic_coefficient[:to]}
              type="number"
              step="0.01"
              label={gettext("To")}
              class="form-control w-1/2 px-3"
            />
          </.inputs_for>
        </.inputs_for>

        <.hidden_input field={@form[:_action]} value={@action} />

        <div class="flex justify-between items-center">
          <label class="flex items-center space-x-2 cursor-pointer text-blue-500 hover:text-blue-600">
            <input type="checkbox" name="entity[dynamic_coefficients_sort][]" class="hidden" />
            <.icon name="hero-plus-circle" class="w-5 h-5" />
            <span>{gettext("Add Dynamic Coefficient")}</span>
          </label>
          <.button
            id="competition-submit-btn"
            type="submit"
            phx-disable-with={gettext("Saving...")}
            class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700"
          >
            {gettext("Save Competition")}
          </.button>
        </div>
        <div class="modal-action">
          <button
            id="competition-save-btn"
            type="submit"
            phx-value-action={@action}
            class={submit_state_class(@form)}
          >
            {gettext("Save")}
          </button>
          <input
            type="reset"
            phx-click={JS.remove_class("modal-open", to: "#new-competition-dialog")}
            class="btn btn-md btn-ghost"
            value={gettext("Cancel")}
          />
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{form: changeset} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(changeset)
     end)}
  end

  @impl true
  def handle_event("validate", %{} = competition_params, socket) do
    # The parent can pass either :entity or :competition as the struct
    entity = socket.assigns[:entity] || socket.assigns[:competition] || %SM.Competitions.Competition{}
    changeset = Competitions.change(entity, competition_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"competition" => competition_params}, socket) do
    save_competition(socket, socket.assigns.action, competition_params)
  end

  defp save_competition(socket, :edit_competition, competition_params) do
    case Competitions.update(socket.assigns.competition, competition_params) do
      {:ok, competition} ->
        notify_parent({:saved, competition})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Competition updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_competition(socket, :new_competition, competition_params) do
    case Competitions.create(competition_params) do
      {:ok, competition} ->
        notify_parent({:saved, competition})

        # When used from NewCompetition page, redirect to participants
        # When used from Admin, use the patch assign if provided
        socket = put_flash(socket, :info, gettext("Competition created successfully"))

        socket =
          if Map.has_key?(socket.assigns, :patch) and socket.assigns.patch do
            push_patch(socket, to: socket.assigns.patch)
          else
            push_navigate(socket, to: "/organize/#{competition.id}/participants")
          end

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
