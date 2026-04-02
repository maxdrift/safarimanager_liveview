defmodule SMWeb.Live.Admin.Competitions.IndexTest do
  @moduledoc """
  Regression tests for admin competition create/edit LiveView.

  Ensures `phx-change` validation receives the full `entity` param tree (including
  nested `competitions_evaluations`) so evaluation selects are not cleared.
  """
  use SMWeb.ConnCase

  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.Competitions

  describe "edit competition / validate" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation]

    setup %{organization: organization, evaluation: evaluation} do
      {:ok, competition} =
        Competitions.create(%{
          "name" => "Regression test competition",
          "type" => :qualification,
          "organization_id" => organization.id,
          "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
        })

      %{competition: competition, evaluation: evaluation}
    end

    test "validate keeps allowed evaluation selections and leaves Save enabled", %{
      conn: conn,
      competition: competition,
      evaluation: evaluation
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/competitions/#{competition.id}/edit")

      assert has_element?(view, "#admin-competition-form")

      html_after =
        view
        |> form("#admin-competition-form",
          entity: %{"name" => competition.name <> " (updated)"}
        )
        |> render_change()

      assert evaluation_option_selected?(html_after, evaluation.id),
             "expected the allowed evaluation to stay selected after validate"

      submit_html =
        view
        |> element(~s|#admin-competition-form button[type="submit"]|)
        |> render()

      assert submit_html =~ "btn-success"
      refute submit_html =~ "btn-disabled"
    end
  end

  defp evaluation_option_selected?(html, evaluation_id) do
    esc = Regex.escape(evaluation_id)

    Regex.match?(~r/<option[^>]*value="#{esc}"[^>]*\bselected/s, html) ||
      Regex.match?(~r/<option[^>]*\bselected[^>]*value="#{esc}"/s, html)
  end
end
