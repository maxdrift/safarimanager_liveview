defmodule SMWeb.Features.CompetitionWorkflowTest do
  @moduledoc """
  End-to-end tests for the Competition Workflow.

  Tests the complete lifecycle of a competition:
  1. Setup - Create competition with settings
  2. Enrollment - Register participants/teams with numbers and categories
  3. Photo Import - Upload slides and associate with participants
  4. Selection - Choose slides for jury vs. fixed points, assign subjects
  5. Validation - Review species identification, flag issues
  6. Jury - Jurors evaluate slides
  7. Results - Calculate rankings

  These tests use PhoenixTest for a user-centric testing approach.
  """

  # Using ConnCase with explicit imports to avoid conflicts between
  # PhoenixTest and Phoenix.LiveViewTest functions.
  use SMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PhoenixTest
  import SM.CompetitionsFixtures

  alias SM.Competitions

  # ============================================================================
  # Stage 2: Setup Phase Tests
  # ============================================================================

  describe "Stage 2: Competition Setup" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation]

    @tag :workflow
    test "user can view the new competition page and see the form", %{conn: conn} do
      # Test that the page loads and form elements are present
      {:ok, view, html} = live(conn, ~p"/organize/new")

      # Verify page elements exist
      assert html =~ "new-competition-button"
      assert has_element?(view, "#new-competition-button")
      assert has_element?(view, "#competition-form")
      assert has_element?(view, "#competition-name-input")
      assert has_element?(view, "#competition-organization-input")
      assert has_element?(view, "#competition-type-input")
      assert has_element?(view, "#competition-submit-btn")
    end

    @tag :workflow
    test "user can create a new competition via form submission", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      # Visit the page
      {:ok, view, _html} = live(conn, ~p"/organize/new")

      # Submit the competition form
      {:error, {:live_redirect, %{to: new_path}}} =
        view
        |> form("#competition-form",
          competition: %{
            "name" => "Safari Championship 2026",
            "organization_id" => organization.id,
            "type" => :qualification,
            "competitions_evaluations" => %{
              "0" => %{"evaluation_id" => evaluation.id}
            }
          }
        )
        |> render_submit()

      # Verify redirect path
      assert ["organize", competition_id, "participants"] = String.split(new_path, "/", trim: true)

      # Verify competition was created correctly
      assert {:ok, competition} = Competitions.get(competition_id)
      assert competition.name == "Safari Championship 2026"
      assert competition.organization_id == organization.id
      assert competition.type == :qualification
      assert [assigned_evaluation] = competition.allowed_evaluations
      assert assigned_evaluation.id == evaluation.id
    end

    @tag :workflow
    test "competition appears in the listing after creation", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      # First create the competition
      {:ok, competition} =
        Competitions.create(%{
          "name" => "Test Safari Event",
          "type" => :qualification,
          "organization_id" => organization.id,
          "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
        })

      # Then verify it appears in the listing
      conn
      |> visit(~p"/organize/new")
      |> assert_has("##{competition.id}-competition-tile", text: "Test Safari Event")
    end

    @tag :workflow
    test "form can be submitted with different competition types", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/new")

      # Submit the competition form with national_championship type
      {:error, {:live_redirect, %{to: new_path}}} =
        view
        |> form("#competition-form",
          competition: %{
            "name" => "National Championship 2026",
            "organization_id" => organization.id,
            "type" => :national_championship,
            "competitions_evaluations" => %{
              "0" => %{"evaluation_id" => evaluation.id}
            }
          }
        )
        |> render_submit()

      # Verify redirect path
      assert ["organize", competition_id, "participants"] = String.split(new_path, "/", trim: true)

      # Verify competition was created with correct type
      {:ok, competition} = Competitions.get(competition_id)
      assert competition.name == "National Championship 2026"
      assert competition.type == :national_championship
    end

    @tag :workflow
    test "competition is created with default settings", %{
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, competition} =
        Competitions.create(%{
          "name" => "Default Settings Competition",
          "type" => :qualification,
          "organization_id" => organization.id,
          "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
        })

      {:ok, loaded_competition} = Competitions.get(competition.id)

      # Verify default settings are applied
      settings = loaded_competition.settings
      assert settings.number_of_jurors == 3
      assert settings.evaluations_per_juror == 1
      assert settings.max_jury_slides == 15
      assert settings.max_submitted_slides == 99
      assert settings.proportional_submission == true
    end

    @tag :workflow
    test "competition can be created with team mode enabled", %{
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, competition} =
        Competitions.create(%{
          "name" => "Team Competition",
          "type" => :qualification,
          "organization_id" => organization.id,
          "for_teams" => true,
          "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
        })

      assert competition.for_teams == true
    end

    @tag :workflow
    test "user can navigate to a competition from the listing", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      # Create a competition
      {:ok, competition} =
        Competitions.create(%{
          "name" => "Clickable Competition",
          "type" => :qualification,
          "organization_id" => organization.id,
          "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
        })

      # Visit the listing page
      {:ok, view, _html} = live(conn, ~p"/organize/new")

      # Click on the competition tile (triggers open event)
      {:error, {:live_redirect, %{to: path}}} =
        view
        |> element("##{competition.id}-competition-tile")
        |> render_click()

      assert path =~ "/organize/#{competition.id}/participants"
    end
  end

  # ============================================================================
  # Stage 3: Enrollment Phase Tests
  # ============================================================================

  describe "Stage 3: Participant Enrollment" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_competition,
      :create_category
    ]

    @tag :workflow
    @tag :skip
    test "user can enroll a participant in a competition", %{
      conn: conn,
      competition: competition,
      category: _category
    } do
      conn
      |> visit(~p"/organize/#{competition.id}/participants")
      |> assert_has("h1", text: competition.name)

      # TODO: Implement participant enrollment flow test
    end
  end

  # ============================================================================
  # Stage 4: Photo Import Phase Tests
  # ============================================================================

  describe "Stage 4: Photo Import" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_competition,
      :create_category,
      :register_users,
      :enroll_participants
    ]

    @tag :workflow
    @tag :skip
    test "user can view slides for a competition", %{
      conn: conn,
      competition: competition
    } do
      conn
      |> visit(~p"/organize/#{competition.id}/slides")
      |> assert_has("h1", text: competition.name)

      # TODO: Implement slide import flow test
    end
  end

  # ============================================================================
  # Stage 5: Selection Phase Tests
  # ============================================================================

  describe "Stage 5: Slide Selection" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_competition,
      :create_category,
      :register_users,
      :enroll_participants,
      :create_slides
    ]

    @tag :workflow
    @tag :skip
    test "user can navigate to slide selection", %{
      conn: conn,
      competition: competition
    } do
      conn
      |> visit(~p"/organize/#{competition.id}/slide_selection")
      |> assert_has("h1", text: competition.name)

      # TODO: Implement slide selection flow test
    end
  end

  # ============================================================================
  # Stage 6: Validation Phase Tests
  # ============================================================================

  describe "Stage 6: Validation" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_competition,
      :create_category,
      :register_users,
      :enroll_participants,
      :create_slides,
      :select_slides
    ]

    @tag :workflow
    @tag :skip
    test "user can launch validation workflow", %{
      conn: conn,
      competition: competition
    } do
      conn
      |> visit(~p"/organize/#{competition.id}/validation_launcher")
      |> assert_has("#start-validation-btn")

      # TODO: Implement validation workflow test
    end
  end

  # ============================================================================
  # Stage 7: Jury Phase Tests
  # ============================================================================

  describe "Stage 7: Jury Evaluation" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_competition,
      :create_category,
      :register_users,
      :enroll_participants,
      :enroll_jurors,
      :create_slides,
      :select_slides
    ]

    @tag :workflow
    @tag :skip
    test "user can launch jury session", %{
      conn: conn,
      competition: competition
    } do
      conn
      |> visit(~p"/organize/#{competition.id}/jury_launcher")
      |> assert_has("h1", text: competition.name)

      # TODO: Implement jury workflow test
    end
  end

  # ============================================================================
  # Stage 8: Results Phase Tests
  # ============================================================================

  describe "Stage 8: Results" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_competition,
      :create_category,
      :register_users,
      :enroll_participants,
      :create_slides,
      :select_slides
    ]

    @tag :workflow
    @tag :skip
    test "user can view competition results", %{
      conn: conn,
      competition: competition
    } do
      conn
      |> visit(~p"/organize/#{competition.id}/results")
      |> assert_has("h1", text: competition.name)

      # TODO: Implement results verification test
    end
  end
end
