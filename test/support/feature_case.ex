defmodule SMWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by feature tests
  using PhoenixTest for end-to-end workflow testing.

  Feature tests simulate user interactions across multiple pages
  and LiveViews, testing complete workflows from the user's perspective.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use SMWeb, :verified_routes

      import SMWeb.FeatureCase
      import PhoenixTest
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(SM.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in a user for feature tests.

  Returns the conn with the user logged in and the user struct.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = SM.AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.

  Returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = SM.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
