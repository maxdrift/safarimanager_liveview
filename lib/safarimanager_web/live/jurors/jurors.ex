defmodule SMWeb.Live.Jurors do
  @moduledoc """
  Jurors live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Competitions
  alias SM.Config
  alias SM.Jurors
  alias SM.Utils
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.Layout
  alias SMWeb.Components.StepsHeader
  alias SMWeb.Endpoint
  alias Surface.Components.Form
  alias Surface.Components.Form.TextInput
  alias Surface.Components.LiveRedirect

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("enroll", %{"user-id" => user_id}, socket) do
    competition_id = socket.assigns.competition_id
    max_jurors_count = socket.assigns.competition.settings.number_of_jurors

    socket =
      if Enum.count(socket.assigns.competition.jurors) < max_jurors_count do
        {:ok, _juror} = Jurors.create(%{user_id: user_id, competition_id: competition_id})
        socket
      else
        Logger.warning("Reached max of #{max_jurors_count} Jurors for Competition #{competition_id}")

        put_flash(
          socket,
          :error,
          "#{gettext("Reached max num. of Jurors")}: #{max_jurors_count}"
        )
      end

    {:noreply, socket}
  end

  def handle_event("remove", %{"user-id" => user_id}, socket) do
    {:ok, _juror} = Jurors.delete(user_id, socket.assigns.competition_id)

    {:noreply, socket}
  end

  def handle_event("filter-users", %{"value" => ""}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)
    {:noreply, assign(socket, :users, users)}
  end

  def handle_event("filter-users", %{"value" => value}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :users, users)}
  end

  def handle_event("show-qr-code", %{"user-id" => user_id}, socket) do
    {:ok, user} = Accounts.get_user(user_id)
    {:ok, address} = Config.get_private_network_address()
    host = %{Endpoint.access_struct_url() | host: Utils.ip_to_host(address)}
    voting_url = Utils.juror_voting_url(host, socket.assigns.competition_id, user_id)

    qr_code =
      voting_url
      |> QRCodeEx.encode()
      |> QRCodeEx.svg(shape: "circle", width: 300)

    socket = assign(socket, qr_code: qr_code, full_name: "#{user.last_name} #{user.first_name}", voting_url: voting_url)

    {:noreply, socket}
  end

  def handle_event("hide-qr-code", _params, socket) do
    socket = assign(socket, qr_code: nil, full_name: "", voting_url: nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    _result = if connected?(socket), do: Jurors.subscribe()

    {:ok, competition} = Competitions.get(competition_id)
    users = Accounts.list_enrollable_jurors(competition_id)

    socket =
      assign(socket, competition_id: competition_id, competition: competition, users: users, qr_code: nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Jurors, [:juror, _action], _result}, socket) do
    competition_id = socket.assigns.competition_id
    {:ok, competition} = Competitions.get(competition_id)
    users = Accounts.list_enrollable_jurors(competition_id)

    socket = assign(socket, competition: competition, users: users)

    {:noreply, socket}
  end
end
