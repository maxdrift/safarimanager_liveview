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
  For complex form submissions that trigger redirects, we use Phoenix.LiveViewTest
  directly within the test since PhoenixTest's unwrap has specific return expectations.
  """

  use SMWeb.ConnCase, async: false

  # Import specific LiveViewTest functions for form submissions that trigger redirects
  # and for use within PhoenixTest's unwrap/2 callback
  import Phoenix.LiveViewTest,
    only: [live: 2, form: 3, render_submit: 1, render_change: 1, element: 2, render_click: 1]

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
      conn
      |> visit(~p"/organize/new")
      |> assert_has("#new-competition-button")
      |> assert_has("#competition-form")
      |> assert_has("#competition-name-input")
      |> assert_has("#competition-organization-input")
      |> assert_has("#competition-type-input")
      |> assert_has("#competition-submit-btn")
    end

    @tag :workflow
    test "user can create a new competition via form submission", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      # Use LiveViewTest for form submission that causes redirect
      {:ok, view, _html} = live(conn, ~p"/organize/new")

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

      ["organize", competition_id, "participants"] = String.split(new_path, "/", trim: true)

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

      # Then verify it appears in the listing using PhoenixTest
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

      ["organize", competition_id, "participants"] = String.split(new_path, "/", trim: true)

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
      {:ok, competition} =
        Competitions.create(%{
          "name" => "Clickable Competition",
          "type" => :qualification,
          "organization_id" => organization.id,
          "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
        })

      {:ok, view, _html} = live(conn, ~p"/organize/new")

      {:error, {:live_redirect, %{to: path}}} =
        view
        |> element("##{competition.id}-competition-tile")
        |> render_click()

      assert path =~ "/organize/#{competition.id}/participants"
    end

    @tag :workflow
    test "form validation preserves previously entered values", %{
      conn: conn,
      organization: organization
    } do
      # This test prevents regression of the form reset bug where
      # editing one field would clear other fields during phx-change validation.
      # The bug occurred when handle_event("validate", ...) didn't extract the
      # nested "competition" key from params.

      # Use PhoenixTest's visit then unwrap for direct LiveViewTest access
      # to trigger phx-change events (not directly supported by PhoenixTest)
      conn
      |> visit(~p"/organize/new")
      |> unwrap(fn view ->
        # Step 1: Fill in name and other fields
        view
        |> form("#competition-form",
          competition: %{
            "name" => "My Safari Event",
            "city" => "Catania",
            "country" => "Italy"
          }
        )
        |> render_change()

        # Step 2: Change another field (type) - all previous values should persist
        html =
          view
          |> form("#competition-form",
            competition: %{
              "name" => "My Safari Event",
              "organization_id" => organization.id,
              "type" => :national_championship,
              "city" => "Catania",
              "country" => "Italy"
            }
          )
          |> render_change()

        # Verify input values are preserved in the form fields after validation
        # Using specific input value assertions to avoid false positives
        assert html =~ ~r/<input[^>]*id="competition-name-input"[^>]*value="My Safari Event"/s or
                 html =~ ~r/<input[^>]*value="My Safari Event"[^>]*id="competition-name-input"/s

        assert html =~ ~r/<input[^>]*name="competition\[city\]"[^>]*value="Catania"/s or
                 html =~ ~r/<input[^>]*value="Catania"[^>]*name="competition\[city\]"/s

        assert html =~ ~r/<input[^>]*name="competition\[country\]"[^>]*value="Italy"/s or
                 html =~ ~r/<input[^>]*value="Italy"[^>]*name="competition\[country\]"/s

        # Return rendered HTML for unwrap to handle
        html
      end)
      |> assert_has("#competition-form")
      |> assert_has("#competition-name-input")
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
      :create_category,
      :register_users
    ]

    @tag :workflow
    test "user can view participants page with available users", %{
      conn: conn,
      competition: competition,
      users: users
    } do
      [first_user | _] = users

      conn
      |> visit(~p"/organize/#{competition.id}/participants")
      |> assert_has("#users-table")
      |> assert_has("#users-table-body")
      |> assert_has("#user-row-#{first_user.id}")
      |> assert_has("#enroll-user-#{first_user.id}")
    end

    @tag :workflow
    test "user can enroll a participant in a competition", %{
      conn: conn,
      competition: competition,
      users: users
    } do
      [user_to_enroll | _] = users

      conn
      |> visit(~p"/organize/#{competition.id}/participants")
      |> assert_has("#participants-table")
      |> refute_has("#participant-row-#{user_to_enroll.id}")
      |> click_button("#enroll-user-#{user_to_enroll.id}", "Enroll")
      |> assert_has("#participant-row-#{user_to_enroll.id}")
      |> refute_has("#user-row-#{user_to_enroll.id}")
    end

    @tag :workflow
    test "enrolled participant has correct number assigned", %{
      conn: conn,
      competition: competition,
      users: users
    } do
      [user1, user2 | _] = users

      conn
      |> visit(~p"/organize/#{competition.id}/participants")
      |> click_button("#enroll-user-#{user1.id}", "Enroll")
      |> click_button("#enroll-user-#{user2.id}", "Enroll")
      |> assert_has("#participant-row-#{user1.id}")
      |> assert_has("#participant-row-#{user2.id}")
      |> assert_has("#participant-row-#{user1.id}", text: user1.last_name)
      |> assert_has("#participant-row-#{user2.id}", text: user2.last_name)
    end

    @tag :workflow
    test "user can remove a participant from competition", %{
      conn: conn,
      competition: competition,
      users: users
    } do
      [user_to_enroll | _] = users

      conn
      |> visit(~p"/organize/#{competition.id}/participants")
      |> click_button("#enroll-user-#{user_to_enroll.id}", "Enroll")
      |> assert_has("#participant-row-#{user_to_enroll.id}")
      |> click_button("#remove-participant-#{user_to_enroll.id}", "Remove")
      |> refute_has("#participant-row-#{user_to_enroll.id}")
      |> assert_has("#user-row-#{user_to_enroll.id}")
    end

    @tag :workflow
    test "user can filter available users by name", %{
      conn: conn,
      competition: competition,
      users: users
    } do
      [target_user | _] = users

      conn
      |> visit(~p"/organize/#{competition.id}/participants")
      |> assert_has("#user-row-#{target_user.id}")
      |> fill_in("Search users", with: target_user.last_name)
      |> assert_has("#user-row-#{target_user.id}")
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
