defmodule SMWeb.UserSettingsLive do
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SMWeb.Components.Layout
  alias Surface.Components.Form
  alias Surface.Components.Form.EmailInput
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.PasswordInput
  alias Surface.Components.Form.Submit

  def render(assigns) do
    ~F"""
    <Layout current_user={@current_user} current_page={~p"/users/settings"}>
      <header>
        <h1 class="text-lg font-semibold leading-8">
          Change Email
        </h1>
      </header>

      <Form id="email_form" for={@email_changeset} submit="update_email" change="validate_email">
        <div
          :if={@email_changeset.action == :insert}
          class="phx-no-feedback:hidden alert alert-error shadow-lg"
        >
          <div>
            <Heroicons.Surface.Icon name="exclamation-circle" type="outline" class="h-6 w-6" />
            <span>Oops, something went wrong! Please check the errors below.</span>
          </div>
        </div>
        <Field name={:email} class="form-control">
          <Label class="label">Email</Label>
          <EmailInput opts={required: true} class="input input-bordered" />
          <Label class="label h-7">
            <ErrorTag />
          </Label>
        </Field>

        <Field name={:current_password} class="form-control">
          <Label class="label">Current password</Label>
          <PasswordInput
            name="current_password"
            id="current_password_for_email"
            value={@email_form_current_password}
            opts={required: true}
            class="input input-bordered"
          />
          <Label class="label h-7">
            <ErrorTag />
          </Label>
        </Field>

        <Submit opts={"phx-disable-with": "Changing..."} class="btn btn-outline">Change Email</Submit>
      </Form>

      <header>
        <h1 class="text-lg font-semibold leading-8">
          Change Password
        </h1>
      </header>

      <Form
        id="password_form"
        for={@password_changeset}
        action={~p"/users/log_in?_action=password_updated"}
        method="post"
        change="validate_password"
        submit="update_password"
        trigger_action={@trigger_submit}
      >
        <div
          :if={@password_changeset.action == :insert}
          class="phx-no-feedback:hidden alert alert-error shadow-lg"
        >
          <div>
            <Heroicons.Surface.Icon name="exclamation-circle" type="outline" class="h-6 w-6" />
            <span>Oops, something went wrong! Please check the errors below.</span>
          </div>
        </div>

        <Field name={:email} class="form-control">
          <EmailInput value={@current_email} opts={hidden: true} />
        </Field>

        <Field name={:password} class="form-control">
          <Label class="label">New password</Label>
          <PasswordInput opts={required: true} class="input input-bordered" />
          <Label class="label h-7">
            <ErrorTag />
          </Label>
        </Field>
        <Field name={:password_confirmation} class="form-control">
          <Label class="label">Confirm new password</Label>
          <PasswordInput class="input input-bordered" />
          <Label class="label h-7">
            <ErrorTag />
          </Label>
        </Field>
        <Field name={:current_password} class="form-control">
          <Label class="label">Current password</Label>
          <PasswordInput
            id="current_password_for_password"
            value={@current_password}
            opts={required: true}
            class="input input-bordered"
          />
          <Label class="label h-7">
            <ErrorTag />
          </Label>
        </Field>

        <Submit opts={"phx-disable-with": "Changing..."} class="btn btn-outline">Change Password</Submit>
      </Form>
    </Layout>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_changeset, Accounts.change_user_email(user))
      |> assign(:password_changeset, Accounts.change_user_password(user))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    email_changeset = Accounts.change_user_email(socket.assigns.current_user, user_params)

    socket =
      assign(socket,
        email_changeset: Map.put(email_changeset, :action, :validate),
        email_form_current_password: password
      )

    {:noreply, socket}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, put_flash(socket, :info, info)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_changeset, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => %{"current_password" => password} = user_params} = params
    password_changeset = Accounts.change_user_password(socket.assigns.current_user, user_params)

    {:noreply,
     socket
     |> assign(:password_changeset, Map.put(password_changeset, :action, :validate))
     |> assign(:current_password, password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:trigger_submit, true)
          |> assign(:password_changeset, Accounts.change_user_password(user, user_params))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_changeset, changeset)}
    end
  end
end
