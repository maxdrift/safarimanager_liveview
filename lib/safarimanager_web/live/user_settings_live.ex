defmodule SMWeb.Live.UserSettingsLive do
  @moduledoc false
  use SMWeb, :live_view

  import SMWeb.Components.Layout

  alias SM.Accounts

  on_mount SMWeb.SidebarHook

  def render(assigns) do
    ~H"""
    <.layout current_user={@current_user} current_page={~p"/users/settings"}>
      <header>
        <h1 class="text-lg font-semibold leading-8">
          {gettext("Change Email")}
        </h1>
      </header>

      <.form id="email_form" for={@email_form} phx-submit="update_email" phx-change="validate_email">
        <div :if={@email_form.action == :insert} class="alert alert-error shadow-lg">
          <div>
            <Heroicons.icon name="exclamation-circle" type="outline" class="h-6 w-6" />
            <span>{gettext("Oops, something went wrong! Please check the errors below.")}</span>
          </div>
        </div>
        <.input
          type="email"
          label={gettext("Email")}
          field={@email_form[:email]}
          class="input input-bordered"
          phx-debounce="1000"
          required
        />

        <.input
          type="password"
          label={gettext("Current password")}
          name="current_password"
          value={@email_form_current_password}
          class="input input-bordered"
          phx-debounce="1000"
          required
        />

        <button type="submit" phx-disable-with={gettext("Changing...")} class="btn btn-outline">
          {gettext("Change Email")}
        </button>
      </.form>

      <header class="mt-6">
        <h1 class="text-lg font-semibold leading-8">
          {gettext("Change Password")}
        </h1>
      </header>

      <.form
        id="password_form"
        for={@password_form}
        action={~p"/users/log_in?_action=password_updated"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <div :if={@password_form.action == :insert} class="alert alert-error shadow-lg">
          <div>
            <Heroicons.icon name="exclamation-circle" type="outline" class="h-6 w-6" />
            <span>{gettext("Oops, something went wrong! Please check the errors below.")}</span>
          </div>
        </div>

        <.hidden_input name="email" value={@current_email} />

        <.input
          type="password"
          label={gettext("New password")}
          field={@password_form[:password]}
          class="input input-bordered"
          phx-debounce="1000"
          required
        />

        <.input
          type="password"
          label={gettext("Confirm new password")}
          field={@password_form[:password_confirmation]}
          class="input input-bordered"
          phx-debounce="1000"
          required
        />

        <.input
          id="current_password_for_password"
          type="password"
          label={gettext("Current password")}
          name="current_password"
          value={@current_password}
          class="input input-bordered"
          phx-debounce="1000"
          required
        />

        <button type="submit" phx-disable-with={gettext("Changing...")} class="btn btn-outline">
          {gettext("Change Password")}
        </button>
      </.form>
    </.layout>
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
      |> assign(:email_form, to_form(Accounts.change_user_email(user)))
      |> assign(:password_form, to_form(Accounts.change_user_password(user)))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    email_changeset = Accounts.change_user_email(socket.assigns.current_user, user_params)

    socket =
      assign(socket,
        email_form: to_form(email_changeset, action: :validate),
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
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_changeset = Accounts.change_user_password(socket.assigns.current_user, user_params)

    {:noreply,
     socket
     |> assign(:password_form, to_form(password_changeset, action: :validate))
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
          |> assign(:password_form, to_form(Accounts.change_user_password(user, user_params)))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_form, to_form(changeset))}
    end
  end
end
