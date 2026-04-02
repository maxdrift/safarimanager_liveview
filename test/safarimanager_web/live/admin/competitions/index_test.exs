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

  describe "edit competition / competition_subjects" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation]

    setup %{organization: organization, evaluation: evaluation} do
      alias SM.Subjects

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Admin edit subject #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 3,
          "scientific_name" => "Testus sp."
        })

      {:ok, competition} =
        Competitions.create(%{
          "name" => "Competition with subjects #{n}",
          "type" => :qualification,
          "organization_id" => organization.id,
          "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}],
          "competition_subjects" => %{"0" => %{"subject_id" => subject.id, "coefficient" => 7}}
        })

      %{competition: competition, evaluation: evaluation, subject: subject}
    end

    test "edit form shows subjects fieldset and preserves subject on validate", %{
      conn: conn,
      competition: competition,
      evaluation: evaluation,
      subject: subject
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/competitions/#{competition.id}/edit")

      assert has_element?(view, "#admin-competition-subjects-fieldset")
      assert has_element?(view, "select[name='entity[competition_subjects][0][subject_id]']")

      html_after =
        view
        |> form("#admin-competition-form",
          entity: %{"name" => competition.name <> " (touched)"}
        )
        |> render_change()

      assert evaluation_option_selected?(html_after, evaluation.id)
      assert subject_option_selected?(html_after, subject.id)
    end

    test "submit updates competition subject coefficient", %{
      conn: conn,
      competition: competition,
      subject: subject
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/competitions/#{competition.id}/edit")

      view
      |> form("#admin-competition-form",
        _action: "edit",
        entity: %{
          "competition_subjects" => %{
            "0" => %{"subject_id" => subject.id, "coefficient" => "42"}
          }
        }
      )
      |> render_submit()

      assert {:ok, updated} = Competitions.get(competition.id)
      row = Enum.find(updated.competition_subjects, &(&1.subject_id == subject.id))
      assert row.coefficient == 42
    end
  end

  describe "new competition / subjects required" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation]

    test "submit without an assigned subject shows an error", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/competitions/new")

      html =
        view
        |> form("#admin-competition-form",
          _action: "create",
          entity: %{
            "name" => "Admin comp without subjects",
            "organization_id" => organization.id,
            "type" => "qualification",
            "competitions_evaluations" => %{"0" => %{"evaluation_id" => evaluation.id}},
            "competition_subjects" => %{"0" => %{"subject_id" => "", "coefficient" => "0"}}
          }
        )
        |> render_submit()

      assert html =~ "Add at least one subject"
    end
  end

  defp evaluation_option_selected?(html, evaluation_id) do
    esc = Regex.escape(evaluation_id)

    Regex.match?(~r/<option[^>]*value="#{esc}"[^>]*\bselected/s, html) ||
      Regex.match?(~r/<option[^>]*\bselected[^>]*value="#{esc}"/s, html)
  end

  defp subject_option_selected?(html, subject_id) do
    evaluation_option_selected?(html, subject_id)
  end
end
