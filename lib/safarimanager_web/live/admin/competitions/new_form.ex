defmodule SMWeb.Live.Admin.Competitions.Form do
  @moduledoc """
  Competitions form component.
  """
  use SMWeb, :live_component
  use Gettext, backend: SMWeb.Gettext

  alias SM.Competitions
  alias SM.Competitions.Competition

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
            <.input field={@form[:end_time]} type="datetime-local" label={gettext("End date/time")} />
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
            <Heroicons.icon name="map-pin" type="outline" class="w-4 h-4 inline-block mr-2" />
            {gettext("Location")}
            <span class="text-xs font-normal normal-case ml-2 opacity-60">
              {gettext("(optional)")}
            </span>
          </div>
          <div class="collapse-content">
            <div class="grid grid-cols-12 gap-4 pt-2">
              <div class="col-span-9">
                <.input field={@form[:street_name]} type="text" label={gettext("Street name")} />
              </div>
              <div class="col-span-3">
                <.input field={@form[:street_number]} type="text" label={gettext("Number")} />
              </div>
              <div class="col-span-4">
                <.input field={@form[:postal_code]} type="text" label={gettext("Postal code")} />
              </div>
              <div class="col-span-8">
                <.input field={@form[:city]} type="text" label={gettext("City")} />
              </div>
              <div class="col-span-6">
                <.input field={@form[:state]} type="text" label={gettext("State/Province")} />
              </div>
              <div class="col-span-6">
                <.input field={@form[:country]} type="text" label={gettext("Country")} />
              </div>
            </div>
          </div>
        </div>

        <%!-- Evaluations Section --%>
        <fieldset class="border border-base-300 rounded-lg p-4">
          <legend class="px-2 text-sm font-semibold text-base-content/70 uppercase tracking-wide mb-3">
            <Heroicons.icon name="star" type="outline" class="w-4 h-4 inline-block mr-1" />
            {gettext("Allowed evaluations")}
          </legend>
          <div id="allowed-evaluations-inputs" class="flex flex-wrap gap-2">
            <.inputs_for :let={evaluation} field={@form[:competitions_evaluations]}>
              <.hidden_input name={"#{@form.name}[evaluation_sort][]"} value={evaluation.index} />
              <div class="group flex items-center gap-1 bg-base-200 rounded-lg px-2 py-1.5 hover:bg-base-300 transition-colors">
                <div class="form-control">
                  <select
                    id={evaluation[:evaluation_id].id}
                    name={evaluation[:evaluation_id].name}
                    class="select select-sm select-bordered bg-base-100 border-base-300 focus:border-primary focus:outline-none min-w-[140px] text-sm"
                    phx-debounce="100"
                  >
                    <option value="">{gettext("Select...")}</option>
                    {Phoenix.HTML.Form.options_for_select(
                      Enum.map(@evaluations, &{&1.name, &1.id}),
                      evaluation[:evaluation_id].value
                    )}
                  </select>
                </div>
                <label class="btn btn-square btn-xs border border-error/30 bg-error/5 text-error hover:bg-error/20 hover:border-error/50 transition-colors cursor-pointer">
                  <input
                    type="checkbox"
                    name={"#{@form.name}[evaluation_drop][]"}
                    value={evaluation.index}
                    class="hidden"
                    phx-debounce="100"
                  />
                  <Heroicons.icon name="trash" type="solid" class="w-3 h-3" />
                </label>
              </div>
            </.inputs_for>
          </div>
          <div class="mt-3">
            <label class="btn btn-ghost btn-sm text-primary hover:bg-primary/10">
              <input
                type="checkbox"
                name={"#{@form.name}[evaluation_sort][]"}
                class="hidden"
                phx-debounce="100"
              />
              <Heroicons.icon name="plus-circle" type="outline" class="w-4 h-4" />
              {gettext("Add evaluation")}
            </label>
          </div>
        </fieldset>

        <%!-- Competition Settings Section --%>
        <.inputs_for :let={settings} field={@form[:settings]}>
          <fieldset class="border border-base-300 rounded-lg p-4">
            <legend class="px-2 text-sm font-semibold text-base-content/70 uppercase tracking-wide">
              <Heroicons.icon name="cog-6-tooth" type="outline" class="w-4 h-4 inline-block mr-1" />
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
                field={settings[:submission_bonus_per_slide]}
                type="number"
                step="0.01"
                label={gettext("Submission bonus (per slide)")}
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
              <Heroicons.icon name="variable" type="outline" class="w-4 h-4 inline-block mr-2" />
              {gettext("Dynamic coefficients")}
              <span class="text-xs font-normal normal-case ml-2 opacity-60">
                {gettext("(advanced)")}
              </span>
            </div>
            <div class="collapse-content">
              <div class="space-y-4 pt-2">
                <.inputs_for :let={dynamic_coefficient} field={settings[:dynamic_coefficients]}>
                  <div class="grid grid-cols-4 gap-3 p-3 bg-base-200/50 rounded-lg">
                    <.input field={dynamic_coefficient[:name]} type="text" label={gettext("Name")} />
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
                  <input
                    type="checkbox"
                    name={"#{@form.name}[settings][dynamic_coefficients_sort][]"}
                    class="hidden"
                    phx-debounce="100"
                  />
                  <Heroicons.icon name="plus-circle" type="outline" class="w-5 h-5" />
                  {gettext("Add Dynamic Coefficient")}
                </label>
              </div>
            </div>
          </div>
        </.inputs_for>

        <%!-- Subjects for this competition --%>
        <fieldset class="border border-base-300 rounded-lg p-4" id="competition-subjects-fieldset">
          <legend class="px-2 text-sm font-semibold text-base-content/70 uppercase tracking-wide mb-3">
            <Heroicons.icon name="squares-2x2" type="outline" class="w-4 h-4 inline-block mr-1" />
            {gettext("Subjects and coefficients")}
          </legend>
          <p class="text-sm text-base-content/60 mb-3">
            {gettext(
              "Choose which species are allowed in this competition and set static coefficients. Use the buttons below to load the full catalog or adjust values in bulk."
            )}
          </p>
          <div class="mb-3 overflow-x-auto overflow-y-visible overscroll-x-contain">
            <div class="flex flex-nowrap items-end gap-2 min-w-0 py-0.5">
              <button
                type="button"
                phx-click="subjects-seed-catalog"
                phx-target={@myself}
                class="btn btn-sm btn-outline btn-primary shrink-0 whitespace-nowrap"
              >
                {gettext("Load all from catalog")}
              </button>
              <button
                type="button"
                phx-click="subjects-reset-catalog-coefficients"
                phx-target={@myself}
                class="btn btn-sm btn-outline shrink-0 whitespace-nowrap"
              >
                {gettext("Reset coefficients from catalog")}
              </button>
              <button
                type="button"
                phx-click="subjects-bulk-offset"
                phx-value-delta="-1"
                phx-target={@myself}
                class="btn btn-sm btn-outline shrink-0 whitespace-nowrap"
              >
                {gettext("Decrease all by 1")}
              </button>
              <button
                type="button"
                phx-click="subjects-bulk-offset"
                phx-value-delta="1"
                phx-target={@myself}
                class="btn btn-sm btn-outline shrink-0 whitespace-nowrap"
              >
                {gettext("Increase all by 1")}
              </button>
              <div class="flex flex-nowrap items-end gap-2 shrink-0 border-l border-base-300 pl-2 ml-1">
                <label
                  for="subject-bulk-set-draft"
                  class="text-sm text-base-content/70 whitespace-nowrap self-center pb-0.5"
                >
                  {gettext("Set all to")}
                </label>
                <input
                  type="number"
                  min="0"
                  id="subject-bulk-set-draft"
                  name="subject_bulk_set_draft"
                  value={@subject_bulk_set_draft}
                  class="input input-bordered input-sm w-20 shrink-0"
                  phx-change="subject-bulk-set-draft"
                  phx-target={@myself}
                  phx-debounce="300"
                />
                <button
                  type="button"
                  phx-click="subjects-bulk-set-all"
                  phx-target={@myself}
                  class="btn btn-sm btn-outline shrink-0 whitespace-nowrap"
                >
                  {gettext("Apply")}
                </button>
              </div>
            </div>
          </div>
          <div :if={competition_subjects_errors(@form) != []} class="text-error text-sm mb-2">
            <p :for={msg <- competition_subjects_errors(@form)}>{msg}</p>
          </div>
          <div class="max-h-64 overflow-y-auto border border-base-200 rounded-lg">
            <.inputs_for :let={csrow} field={@form[:competition_subjects]}>
              <.hidden_input name={"#{@form.name}[competition_subject_sort][]"} value={csrow.index} />
              <div class="flex flex-wrap items-end gap-2 p-2 border-b border-base-200 last:border-b-0 bg-base-100">
                <div class="form-control min-w-[200px] flex-1">
                  <label class="label py-0">
                    <span class="label-text text-xs">{gettext("Subject")}</span>
                  </label>
                  <select
                    id={csrow[:subject_id].id}
                    name={csrow[:subject_id].name}
                    class="select select-bordered select-sm w-full"
                    phx-debounce="100"
                  >
                    <option value="">{gettext("Select…")}</option>
                    {Phoenix.HTML.Form.options_for_select(
                      subject_select_options(@subjects),
                      csrow[:subject_id].value
                    )}
                  </select>
                </div>
                <div class="form-control w-28">
                  <label class="label py-0">
                    <span class="label-text text-xs">{gettext("Coeff.")}</span>
                  </label>
                  <.input
                    field={csrow[:coefficient]}
                    type="number"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
                <label class="btn btn-square btn-sm btn-ghost text-error">
                  <input
                    type="checkbox"
                    name={"#{@form.name}[competition_subject_drop][]"}
                    value={csrow.index}
                    class="hidden"
                  />
                  <Heroicons.icon name="trash" type="solid" class="w-4 h-4" />
                </label>
              </div>
            </.inputs_for>
          </div>
          <div class="mt-2">
            <label class="btn btn-ghost btn-sm text-primary">
              <input
                type="checkbox"
                name={"#{@form.name}[competition_subject_sort][]"}
                class="hidden"
              />
              <Heroicons.icon name="plus-circle" type="outline" class="w-4 h-4" />
              {gettext("Add subject row")}
            </label>
          </div>
        </fieldset>

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
            <Heroicons.icon name="check" type="outline" class="w-4 h-4 mr-1" />
            {gettext("Save Competition")}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:subjects, fn -> [] end)
      |> assign_new(:subject_bulk_set_draft, fn -> "" end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"competition" => competition_params}, socket) do
    entity = socket.assigns[:entity] || socket.assigns[:competition] || %Competition{}
    changeset = Competitions.change(entity, competition_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"competition" => competition_params}, socket) do
    save_competition(socket, socket.assigns.action, competition_params)
  end

  def handle_event("subjects-seed-catalog", _params, socket) do
    params =
      socket.assigns.form.source.params
      |> Kernel.||(%{})
      |> Map.put("competition_subjects", Competitions.competition_subject_seed_nested_params())

    {:noreply, rechange_competition_form(socket, params)}
  end

  def handle_event("subjects-reset-catalog-coefficients", _params, socket) do
    params = socket.assigns.form.source.params || %{}
    nested = params["competition_subjects"] || %{}
    new_nested = Competitions.bulk_reset_competition_subject_params_from_catalog(nested)
    {:noreply, rechange_competition_form(socket, Map.put(params, "competition_subjects", new_nested))}
  end

  def handle_event("subjects-bulk-offset", %{"delta" => delta_str}, socket) do
    delta =
      case Integer.parse(delta_str) do
        {d, _} -> d
        :error -> 0
      end

    params = socket.assigns.form.source.params || %{}
    nested = params["competition_subjects"] || %{}
    new_nested = Competitions.bulk_offset_competition_subject_params(nested, delta)
    {:noreply, rechange_competition_form(socket, Map.put(params, "competition_subjects", new_nested))}
  end

  def handle_event("subject-bulk-set-draft", %{"subject_bulk_set_draft" => v}, socket) do
    {:noreply, assign(socket, :subject_bulk_set_draft, v)}
  end

  def handle_event("subject-bulk-set-draft", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("subjects-bulk-set-all", _params, socket) do
    value =
      case Integer.parse(to_string(socket.assigns.subject_bulk_set_draft || "")) do
        {n, _} -> max(0, n)
        :error -> 0
      end

    params = socket.assigns.form.source.params || %{}
    nested = params["competition_subjects"] || %{}
    new_nested = Competitions.bulk_set_competition_subject_params(nested, value)
    {:noreply, rechange_competition_form(socket, Map.put(params, "competition_subjects", new_nested))}
  end

  defp rechange_competition_form(socket, params) do
    entity = socket.assigns[:entity] || socket.assigns[:competition] || %Competition{}
    cs = Competitions.change(entity, params)
    assign(socket, form: to_form(cs, action: :validate))
  end

  defp save_competition(socket, :edit_competition, competition_params) do
    competition = socket.assigns.competition

    if Competitions.competition_subject_removal_blocked?(competition.id, competition_params) do
      msg = gettext("Cannot remove a subject that still has slides in this competition.")

      cs =
        competition
        |> Competitions.change(competition_params)
        |> Ecto.Changeset.add_error(:competition_subjects, msg)

      {:noreply, assign(socket, form: to_form(cs))}
    else
      case Competitions.update(competition, competition_params) do
        {:ok, updated} ->
          notify_parent({:saved, updated})

          {:noreply,
           socket
           |> put_flash(:info, gettext("Competition updated successfully"))
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  defp save_competition(socket, :new_competition, competition_params) do
    entity = socket.assigns[:entity] || %Competition{}

    case validate_at_least_one_subject_row(competition_params) do
      {:error, msg} ->
        cs =
          entity
          |> Competitions.change(competition_params)
          |> Ecto.Changeset.add_error(:competition_subjects, msg)

        {:noreply, assign(socket, form: to_form(cs))}

      :ok ->
        case Competitions.create(competition_params) do
          {:ok, competition} ->
            notify_parent({:saved, competition})
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
  end

  defp validate_at_least_one_subject_row(params) do
    if Competitions.competition_params_have_assigned_subject?(params) do
      :ok
    else
      {:error, gettext("Add at least one subject (use “Load all from catalog” or “Add subject row”).")}
    end
  end

  defp competition_subjects_errors(%Phoenix.HTML.Form{source: %Ecto.Changeset{} = cs}) do
    cs.errors
    |> Keyword.get_values(:competition_subjects)
    |> Enum.map(&elem(&1, 0))
  end

  defp competition_subjects_errors(_), do: []

  defp subject_select_options(subjects) do
    Enum.map(subjects, fn s ->
      {"#{s.numeric_id} — #{s.name}", s.id}
    end)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
