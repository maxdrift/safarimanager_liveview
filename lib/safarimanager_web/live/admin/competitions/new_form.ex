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
    <div class="max-h-[80vh] overflow-y-auto pr-2">
      <.form
        for={@form}
        id="competition-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <%!-- Basic Information Section --%>
        <fieldset class="border border-base-300 rounded-lg p-4">
          <legend class="px-2 text-sm font-semibold text-base-content/70 uppercase tracking-wide">
            {gettext("Basic Information")}
          </legend>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="md:col-span-2">
              <.input
                id="competition-name-input"
                field={@form[:name]}
                type="text"
                label={gettext("Name")}
                required
              />
            </div>
            <.input
              id="competition-organization-input"
              field={@form[:organization_id]}
              type="select"
              options={Enum.map(@organizations, &{&1.name, &1.id})}
              label={gettext("Organization")}
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
            />
            <.input
              field={@form[:start_time]}
              type="datetime-local"
              label={gettext("Start date/time")}
            />
            <.input
              field={@form[:end_time]}
              type="datetime-local"
              label={gettext("End date/time")}
            />
            <div class="md:col-span-2 flex items-center">
              <.input
                id="competition-for-teams-input"
                field={@form[:for_teams]}
                type="checkbox"
                label={gettext("For teams")}
              />
            </div>
          </div>
        </fieldset>

        <%!-- Location Section (Collapsible) --%>
        <div class="collapse collapse-arrow border border-base-300 rounded-lg bg-base-100">
          <input type="checkbox" class="peer" />
          <div class="collapse-title font-semibold text-base-content/70 uppercase tracking-wide text-sm">
            <.icon name="hero-map-pin" class="w-4 h-4 inline-block mr-2" />
            {gettext("Location")}
            <span class="text-xs font-normal normal-case ml-2 opacity-60">{gettext("(optional)")}</span>
          </div>
          <div class="collapse-content">
            <div class="grid grid-cols-12 gap-4 pt-2">
              <div class="col-span-9">
                <.input
                  field={@form[:street_name]}
                  type="text"
                  label={gettext("Street name")}
                />
              </div>
              <div class="col-span-3">
                <.input
                  field={@form[:street_number]}
                  type="text"
                  label={gettext("Number")}
                />
              </div>
              <div class="col-span-4">
                <.input
                  field={@form[:postal_code]}
                  type="text"
                  label={gettext("Postal code")}
                />
              </div>
              <div class="col-span-8">
                <.input
                  field={@form[:city]}
                  type="text"
                  label={gettext("City")}
                />
              </div>
              <div class="col-span-6">
                <.input
                  field={@form[:state]}
                  type="text"
                  label={gettext("State/Province")}
                />
              </div>
              <div class="col-span-6">
                <.input
                  field={@form[:country]}
                  type="text"
                  label={gettext("Country")}
                />
              </div>
            </div>
          </div>
        </div>

        <%!-- Evaluations Section --%>
        <fieldset class="border border-base-300 rounded-lg p-4">
          <legend class="px-2 text-sm font-semibold text-base-content/70 uppercase tracking-wide">
            <.icon name="hero-star" class="w-4 h-4 inline-block mr-1" />
            {gettext("Allowed evaluations")}
          </legend>
          <div id="allowed-evaluations-inputs" class="space-y-2">
            <.inputs_for :let={evaluation} field={@form[:competitions_evaluations]}>
              <div class="flex items-end gap-2">
                <.hidden_input name="entity[evaluation_sort][]" value={evaluation.index} />
                <div class="flex-grow">
                  <.input
                    field={evaluation[:evaluation_id]}
                    type="select"
                    options={Enum.map(@evaluations, &{&1.name, &1.id})}
                    label={gettext("Evaluation")}
                  />
                </div>
                <label class="btn btn-ghost btn-square btn-sm mb-1 text-error hover:bg-error/10">
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
          <div class="mt-3">
            <label class="btn btn-ghost btn-sm text-primary hover:bg-primary/10">
              <input type="checkbox" name="entity[evaluation_sort][]" class="hidden" />
              <.icon name="hero-plus-circle" class="w-5 h-5" />
              {gettext("Add evaluation")}
            </label>
          </div>
        </fieldset>

        <%!-- Competition Settings Section --%>
        <.inputs_for :let={settings} field={@form[:settings]}>
          <fieldset class="border border-base-300 rounded-lg p-4">
            <legend class="px-2 text-sm font-semibold text-base-content/70 uppercase tracking-wide">
              <.icon name="hero-cog-6-tooth" class="w-4 h-4 inline-block mr-1" />
              {gettext("Competition Settings")}
            </legend>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%!-- Jury Settings --%>
              <div class="md:col-span-2 lg:col-span-3">
                <h4 class="text-sm font-medium text-base-content/60 mb-2 border-b border-base-200 pb-1">
                  {gettext("Jury")}
                </h4>
              </div>
              <.input
                field={settings[:number_of_jurors]}
                type="number"
                label={gettext("Number of jurors")}
              />
              <.input
                field={settings[:evaluations_per_juror]}
                type="number"
                label={gettext("Evaluations per juror")}
              />
              <.input
                field={settings[:max_jury_slides]}
                type="number"
                label={gettext("Max slides for jury")}
              />

              <%!-- Submission Settings --%>
              <div class="md:col-span-2 lg:col-span-3 mt-4">
                <h4 class="text-sm font-medium text-base-content/60 mb-2 border-b border-base-200 pb-1">
                  {gettext("Submission")}
                </h4>
              </div>
              <.input
                field={settings[:max_submitted_slides]}
                type="number"
                label={gettext("Max submitted slides")}
              />
              <.input
                field={settings[:submission_ratio]}
                type="number"
                step="0.01"
                label={gettext("Submission ratio")}
              />
              <div class="flex items-center pt-6">
                <.input
                  field={settings[:proportional_submission]}
                  type="checkbox"
                  label={gettext("Proportional submission")}
                />
              </div>

              <%!-- Scoring Settings --%>
              <div class="md:col-span-2 lg:col-span-3 mt-4">
                <h4 class="text-sm font-medium text-base-content/60 mb-2 border-b border-base-200 pb-1">
                  {gettext("Scoring")}
                </h4>
              </div>
              <.input
                field={settings[:fixed_points_multiplier]}
                type="number"
                step="0.01"
                label={gettext("Fixed points multiplier")}
              />
              <.input
                field={settings[:penalty_amount]}
                type="number"
                step="0.01"
                label={gettext("Penalty amount")}
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
              />
            </div>
          </fieldset>

          <%!-- Dynamic Coefficients Section (Collapsible) --%>
          <div class="collapse collapse-arrow border border-base-300 rounded-lg bg-base-100">
            <input type="checkbox" class="peer" />
            <div class="collapse-title font-semibold text-base-content/70 uppercase tracking-wide text-sm">
              <.icon name="hero-variable" class="w-4 h-4 inline-block mr-2" />
              {gettext("Dynamic coefficients")}
              <span class="text-xs font-normal normal-case ml-2 opacity-60">{gettext("(advanced)")}</span>
            </div>
            <div class="collapse-content">
              <div class="space-y-4 pt-2">
                <.inputs_for :let={dynamic_coefficient} field={settings[:dynamic_coefficients]}>
                  <div class="grid grid-cols-4 gap-3 p-3 bg-base-200/50 rounded-lg">
                    <.input
                      field={dynamic_coefficient[:name]}
                      type="text"
                      label={gettext("Name")}
                    />
                    <.input
                      field={dynamic_coefficient[:value]}
                      type="number"
                      step="0.01"
                      label={gettext("Value")}
                    />
                    <.input
                      field={dynamic_coefficient[:from]}
                      type="number"
                      step="0.01"
                      label={gettext("From")}
                    />
                    <.input
                      field={dynamic_coefficient[:to]}
                      type="number"
                      step="0.01"
                      label={gettext("To")}
                    />
                  </div>
                </.inputs_for>
                <label class="btn btn-ghost btn-sm text-primary hover:bg-primary/10">
                  <input type="checkbox" name="entity[dynamic_coefficients_sort][]" class="hidden" />
                  <.icon name="hero-plus-circle" class="w-5 h-5" />
                  {gettext("Add Dynamic Coefficient")}
                </label>
              </div>
            </div>
          </div>
        </.inputs_for>

        <.hidden_input field={@form[:_action]} value={@action} />

        <%!-- Modal Actions --%>
        <div class="modal-action border-t border-base-300 pt-4 mt-6 sticky bottom-0 bg-base-100 -mx-4 px-4 pb-2">
          <input
            type="reset"
            phx-click={JS.remove_class("modal-open", to: "#new-competition-dialog")}
            class="btn btn-ghost"
            value={gettext("Cancel")}
          />
          <button
            id="competition-save-btn"
            type="submit"
            phx-disable-with={gettext("Saving...")}
            class={submit_state_class(@form)}
          >
            <.icon name="hero-check" class="w-4 h-4 mr-1" />
            {gettext("Save Competition")}
          </button>
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
  def handle_event("validate", %{"competition" => competition_params}, socket) do
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
