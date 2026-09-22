defmodule SMWeb.Live.NewCompetitionTest do
  @moduledoc """
  Regression tests for the organize New Competition form save button state.

  Green (`btn-success`) requires `phx-change` validation with a valid changeset:
  name, organization, type, at least one allowed evaluation, and catalog subjects
  (auto-seeded on mount when the catalog is non-empty).
  """
  use SMWeb.ConnCase

  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.Competitions
  alias SM.Competitions.Competition

  describe "save competition button" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_evaluation,
      :create_catalog_subject
    ]

    test "is disabled until validate runs with minimal required fields", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, view, html} = live(conn, ~p"/organize/new")

      assert has_element?(view, "#competition-save-btn")
      refute save_button_enabled_in_html?(html)

      html_after =
        view
        |> form("#competition-form",
          competition: minimal_competition_params(organization, evaluation)
        )
        |> render_change()

      assert save_button_enabled_in_html?(html_after)
    end

    test "submit succeeds with minimal required fields when catalog is auto-seeded", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/new")

      {:error, {:live_redirect, %{to: path}}} =
        view
        |> form("#competition-form",
          competition: minimal_competition_params(organization, evaluation)
        )
        |> render_submit()

      assert path =~ "/organize/"
      assert path =~ "/participants"

      competition_id =
        path
        |> String.split("/", trim: true)
        |> Enum.at(1)

      assert {:ok, competition} = Competitions.get(competition_id)
      assert competition.name == "Minimal competition"
      assert competition.competition_subjects != []
    end

    test "stays enabled after loading catalog before the first field change", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/new")

      view
      |> element("button", "Load all from catalog")
      |> render_click()

      html_after =
        view
        |> form("#competition-form",
          competition: minimal_competition_params(organization, evaluation)
        )
        |> render_change()

      assert save_button_enabled_in_html?(html_after)
      assert has_element?(view, "select[name='competition[competitions_evaluations][0][evaluation_id]']")
    end
  end

  describe "save competition button without catalog subjects" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation]

    test "stays disabled until the catalog has subjects to seed", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/new")

      html_after =
        view
        |> form("#competition-form",
          competition: minimal_competition_params(organization, evaluation)
        )
        |> render_change()

      refute save_button_enabled_in_html?(html_after)
      assert html_after =~ "Add at least one subject"
    end
  end

  describe "minimal competition changeset" do
    setup [:create_organization, :create_evaluation]

    test "required fields validate", %{organization: organization, evaluation: evaluation} do
      cs =
        %Competition{}
        |> Competitions.change(minimal_competition_params(organization, evaluation))
        |> Map.put(:action, :validate)

      assert cs.valid?, inspect(traverse_errors(cs))
    end
  end

  defp minimal_competition_params(organization, evaluation) do
    %{
      "name" => "Minimal competition",
      "organization_id" => organization.id,
      "type" => "qualification",
      "competitions_evaluations" => %{"0" => %{"evaluation_id" => evaluation.id}}
    }
  end

  defp save_button_enabled_in_html?(html) do
    classes = save_button_classes(html)

    class_list = String.split(classes)
    "btn-success" in class_list and "btn-disabled" not in class_list
  end

  defp save_button_classes(html) do
    case Regex.run(~r/<button\b[^>]*\bid="competition-save-btn"[^>]*>/, html) do
      [tag] ->
        class_attr_from_tag(tag)

      _ ->
        case Regex.run(~r/<button\b[^>]*\bclass="([^"]*)"[^>]*\bid="competition-save-btn"/, html) do
          [_, classes] -> classes
          _ -> ""
        end
    end
  end

  defp class_attr_from_tag(tag) do
    case Regex.run(~r/\bclass="([^"]*)"/, tag) do
      [_, classes] -> classes
      _ -> ""
    end
  end

  defp traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
  end
end
