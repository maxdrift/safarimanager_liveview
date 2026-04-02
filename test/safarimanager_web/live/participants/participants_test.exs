defmodule SMWeb.Live.ParticipantsTest do
  @moduledoc """
  Tests for the Participants LiveView, including form validation,
  collapse toggle, reset button, and category change handling.
  """
  use SMWeb.ConnCase

  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.Accounts
  alias SM.Participants

  describe "Register New User form validation" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation, :create_competition, :create_category]

    test "form validation shows errors when fields are invalid", %{
      conn: conn,
      competition: competition,
      organization: organization,
      category: category
    } do
      {:ok, view, html} = live(conn, ~p"/organize/#{competition.id}/participants")

      assert html =~ "Register New User"
      assert has_element?(view, "#participants-new-user-form")

      html =
        view
        |> form("#participants-new-user-form",
          entity: %{
            "first_name" => "John",
            "email" => "invalid-email",
            "organization_id" => organization.id,
            "category_id" => category.id
          }
        )
        |> render_change()

      assert html =~ "can&#39;t be blank" or
               html =~ "can't be blank" or
               html =~ "must have the @ sign",
             "Expected validation errors for missing last_name or invalid email"
    end

    test "form validation works with valid data", %{
      conn: conn,
      competition: competition,
      organization: organization,
      category: category
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/participants")

      # Fill form with valid data
      html =
        view
        |> form("#participants-new-user-form",
          entity: %{
            "first_name" => "John",
            "last_name" => "Doe",
            "email" => "john.doe@example.com",
            "organization_id" => organization.id,
            "category_id" => category.id
          }
        )
        |> render_change()

      # Form should be valid (no errors shown)
      refute html =~ "can&#39;t be blank"
      refute html =~ "can't be blank"
      refute html =~ "must have the @ sign"
    end

    test "form validation triggers phx-change event with invalid email", %{
      conn: conn,
      competition: competition
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/participants")

      html =
        view
        |> form("#participants-new-user-form", entity: %{"email" => "not-an-email"})
        |> render_change()

      assert html =~ "must have the @ sign" or
               html =~ "can&#39;t be blank" or
               html =~ "can't be blank",
             "Expected validation error for invalid email"
    end

    test "register button becomes enabled when form is valid", %{
      conn: conn,
      competition: competition,
      organization: organization,
      category: category
    } do
      {:ok, view, html} = live(conn, ~p"/organize/#{competition.id}/participants")

      assert html =~ ~r/<button[^>]*type="submit"[^>]*disabled[^>]*>.*Register/s,
             "Register button should be disabled initially"

      html =
        view
        |> form("#participants-new-user-form",
          entity: %{
            "first_name" => "John",
            "last_name" => "Doe",
            "email" => "john.doe@example.com",
            "organization_id" => organization.id,
            "category_id" => category.id
          }
        )
        |> render_change()

      refute html =~ ~r/<button[^>]*type="submit"[^>]*disabled[^>]*>.*Register/s,
             "Register button should be enabled when form is valid"
    end

    test "register button stays disabled when form is invalid", %{
      conn: conn,
      competition: competition
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/participants")

      # Fill form with invalid data (missing required last_name)
      html =
        view
        |> form("#participants-new-user-form",
          entity: %{
            "first_name" => "John",
            "email" => "john@example.com"
            # last_name is missing (required field)
          }
        )
        |> render_change()

      # Button should remain disabled when form is invalid
      assert html =~ ~r/<button[^>]*type="submit"[^>]*disabled[^>]*>.*Register/s,
             "Register button should stay disabled when form is invalid (missing required fields)"
    end
  end

  describe "Register New User collapse and reset" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation, :create_competition, :create_category]

    test "toggling collapse checkbox updates expand state", %{conn: conn, competition: competition} do
      {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/participants")

      # Collapse starts closed (checkbox not checked)
      refute has_element?(view, "#register-new-user-collapse input[type=checkbox][checked]")

      # Click the checkbox to expand
      view
      |> element("#register-new-user-collapse input[type=checkbox]")
      |> render_click()

      # Checkbox should now be checked (collapse open)
      assert has_element?(view, "#register-new-user-collapse input[type=checkbox][checked]")
    end

    test "reset button clears the form and disables register button", %{
      conn: conn,
      competition: competition,
      organization: organization,
      category: category
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/participants")

      # Fill form with valid data so Register becomes enabled
      view
      |> form("#participants-new-user-form",
        entity: %{
          "first_name" => "John",
          "last_name" => "Doe",
          "email" => "john.doe@example.com",
          "organization_id" => organization.id,
          "category_id" => category.id
        }
      )
      |> render_change()

      # Click Reset
      view
      |> element("button[phx-click=reset-new-user]")
      |> render_click()

      # Register button should be disabled again (form cleared)
      assert render(view) =~ ~r/<button[^>]*type="submit"[^>]*disabled[^>]*>.*Register/s
    end
  end

  describe "Category selection" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_evaluation,
      :create_competition,
      :create_category,
      :enroll_one_participant
    ]

    test "category-change with empty category_id does not update participant", %{
      conn: conn,
      competition: competition,
      participant: participant,
      category: category
    } do
      {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/participants")

      original_category_id = participant.category_id
      assert original_category_id == category.id

      # Trigger category-change with empty category_id (e.g. placeholder selected)
      view
      |> element("#category-form-#{participant.user_id}")
      |> render_change(%{"category_id" => "", "user_id" => participant.user_id})

      # Participant category should be unchanged in DB
      {:ok, updated} = Participants.get(participant.user_id, competition.id)
      assert updated.category_id == original_category_id
    end
  end

  defp enroll_one_participant(%{competition: competition, organization: organization, category: category}) do
    user = SM.AccountsFixtures.user_fixture()

    {:ok, user} =
      Accounts.update(user, %{
        last_name: user.last_name || "Test",
        first_name: user.first_name || "User",
        organization_id: organization.id,
        category_id: category.id
      })

    number = Participants.get_next_participant_number(competition.id)

    {:ok, participant} =
      Participants.create(%{
        user_id: user.id,
        competition_id: competition.id,
        category_id: category.id,
        number: number
      })

    %{participant: participant, enrollable_user: user}
  end
end
