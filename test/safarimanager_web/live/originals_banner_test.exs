defmodule SMWeb.Live.OriginalsBannerTest do
  use SMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.CompetitionDirectories

  setup [
    :register_and_log_in_user,
    :create_organization,
    :create_evaluation,
    :create_competition
  ]

  test "reachability broadcasts toggle the banner without reaching the LiveView", %{
    conn: conn,
    competition: competition
  } do
    {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/results")
    refute has_element?(view, "#originals-unreachable-banner")

    send(view.pid, {CompetitionDirectories, [:originals_reachability, competition.id], :unreachable})
    assert has_element?(view, "#originals-unreachable-banner")

    send(view.pid, {CompetitionDirectories, [:originals_reachability, Ecto.UUID.generate()], :reachable})
    assert has_element?(view, "#originals-unreachable-banner")

    view |> element("#originals-retry") |> render_click()
    refute has_element?(view, "#originals-unreachable-banner")
  end
end
