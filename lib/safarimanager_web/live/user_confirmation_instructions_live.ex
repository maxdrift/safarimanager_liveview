defmodule SMWeb.Live.UserConfirmationInstructionsLive do
  @moduledoc false
  use SMWeb, :live_view

  alias SM.Accounts

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header><%= gettext("Resend confirmation instructions") %></.header>

    <.simple_form
      :let={f}
      for={%{}}
      as={:user}
      id="resend_confirmation_form"
      phx-submit="send_instructions"
    >
      <.input field={{f, :email}} type="email" label="Email" required />
      <:actions>
        <.button phx-disable-with={gettext("Sending...")}>
          <%= gettext("Resend confirmation instructions") %>
        </.button>
      </:actions>
    </.simple_form>

    <p>
      <.link href={~p"/users/register"}><%= gettext("Register") %></.link>
      | <.link href={~p"/users/log_in"}><%= gettext("Log in") %></.link>
    </p>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      gettext(
        "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."
      )

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
