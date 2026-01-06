defmodule SMWeb.Components.UserForm do
  @moduledoc """
  User form component.
  """
  use SMWeb, :component

  attr :id, :string, required: true
  attr :action, :atom, values: [:create, :edit]
  attr :entity, SM.Accounts.User, required: true
  attr :form, :any, required: true
  attr :validate, :string, required: true
  attr :submit, :string, required: true
  attr :redirect_to, :string
  attr :organizations, :list, default: []
  attr :categories, :list, default: []

  slot :inner_block

  def user_form(assigns) do
    ~H"""
    <.form
      id={@id}
      for={@form}
      phx-change={@validate}
      phx-submit={@submit}
      as={:entity}
      autocomplete="off"
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <.input
          type="text"
          label={gettext("Last Name")}
          field={@form[:last_name]}
          class={state_class("input input-bordered", @form, :last_name, [])}
          phx-debounce="1000"
          required
        />
        <.input
          type="text"
          label={gettext("First Name")}
          field={@form[:first_name]}
          class={state_class("input input-bordered", @form, :first_name, [])}
          phx-debounce="1000"
        />
        <.input
          type="email"
          label={gettext("Email")}
          field={@form[:email]}
          class={state_class("input input-bordered", @form, :email, [])}
          phx-debounce="1000"
        />
        <.input
          type="select"
          label={gettext("Organization")}
          field={@form[:organization_id]}
          options={Enum.map(@organizations, &{&1.name, &1.id})}
          prompt={gettext("Select an organization...")}
          class={state_class("select select-bordered", @form, :organization_id, [])}
        />
        <.input
          type="select"
          label={gettext("Category")}
          field={@form[:category_id]}
          options={Enum.map(@categories, &{&1.name, &1.id})}
          prompt={gettext("Select a category...")}
          class={state_class("select select-bordered", @form, :category_id, [])}
        />
        <.hidden_input name={:_action} value={@action} />
      </div>
      {render_slot(@inner_block)}
    </.form>
    """
  end
end
