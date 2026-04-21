defmodule SMWeb.Live.ValidationLauncherTest do
  @moduledoc """
  Regression tests for ValidationLauncher LiveView actions.

  Ensures phx-value keys match handle_event param patterns (e.g. `slide-id`
  vs `slide_id`) so dropdown actions do not raise FunctionClauseError.
  """
  use SMWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.Repo
  alias SM.Slides
  alias SM.Slides.SlideFlag
  alias SM.Subjects

  @fixtures_setup [
    :register_and_log_in_user,
    :create_organization,
    :create_competition,
    :create_category,
    :register_users,
    :enroll_participants,
    :create_slides,
    :seed_subjects_for_selection,
    :select_slides,
    :add_slide_flags
  ]

  defp seed_subjects_for_selection(_context) do
    # select_slides/1 needs ≥8 subjects (see CompetitionsFixtures.select_slides/1)
    base = System.unique_integer([:positive])

    for n <- 1..8 do
      {:ok, _} =
        Subjects.create(%{
          "name" => "Validation launcher subject #{base}-#{n}",
          "numeric_id" => base * 100 + n,
          "type" => :fish,
          "coefficient" => 1
        })
    end

    :ok
  end

  defp launcher_path(competition_id), do: "/organize/#{competition_id}/validation_launcher"

  defp validation_detail_row(slide_id), do: "#validation-detail-row-#{slide_id}"

  describe "dropdown actions (slide-id params)" do
    setup @fixtures_setup

    test "apply-subject-correction succeeds", %{conn: conn, competition: competition} do
      flagged_slide_id =
        Repo.one!(
          from(sf in SlideFlag,
            where: sf.type == :wrong_subject,
            select: sf.slide_id,
            limit: 1
          )
        )

      {:ok, slide_before} = Slides.get(flagged_slide_id)
      assert Enum.any?(slide_before.slide_flags, &(&1.type == :wrong_subject))

      {:ok, view, html} = live(conn, ~p"/organize/#{competition.id}/validation_launcher")

      assert html =~ "validation-results-table"
      assert html =~ flagged_slide_id

      row = validation_detail_row(flagged_slide_id)

      assert {:error, {:live_redirect, %{to: redirect_to}}} =
               view
               |> element("#{row} a[phx-click=\"apply-subject-correction\"]")
               |> render_click()

      assert redirect_to == launcher_path(competition.id)

      {:ok, slide_after} = Slides.get(flagged_slide_id)
      refute Enum.any?(slide_after.slide_flags, &(&1.type == :wrong_subject))
    end

    test "move-slide-to-fixed succeeds", %{conn: conn, competition: competition} do
      jury_slide_id =
        Repo.one!(
          from(sf in SlideFlag,
            where: sf.type == :wrong_subject,
            select: sf.slide_id,
            limit: 1
          )
        )

      {:ok, slide_before} = Slides.get(jury_slide_id)
      assert slide_before.status == :submitted_jury

      {:ok, view, _} = live(conn, ~p"/organize/#{competition.id}/validation_launcher")

      row = validation_detail_row(jury_slide_id)

      assert {:error, {:live_redirect, %{to: redirect_to}}} =
               view
               |> element("#{row} a[phx-click=\"move-slide-to-fixed\"]")
               |> render_click()

      assert redirect_to == launcher_path(competition.id)

      {:ok, slide_after} = Slides.get(jury_slide_id)
      assert slide_after.status == :submitted_fixed
    end

    test "move-slide-to-jury succeeds", %{conn: conn, competition: competition} do
      unrecognizable_slide_id =
        Repo.one!(
          from(sf in SlideFlag,
            where: sf.type == :unrecognizable,
            select: sf.slide_id,
            limit: 1
          )
        )

      {:ok, slide} = Slides.get(unrecognizable_slide_id)
      {:ok, _} = Slides.update(slide, %{"status" => :submitted_fixed})

      {:ok, view, _} = live(conn, ~p"/organize/#{competition.id}/validation_launcher")

      row = validation_detail_row(unrecognizable_slide_id)

      assert {:error, {:live_redirect, %{to: redirect_to}}} =
               view
               |> element("#{row} a[phx-click=\"move-slide-to-jury\"]")
               |> render_click()

      assert redirect_to == launcher_path(competition.id)

      {:ok, slide_after} = Slides.get(unrecognizable_slide_id)
      assert slide_after.status == :submitted_jury
    end

    test "move-slide-to-discarded succeeds", %{conn: conn, competition: competition} do
      distinction_slide_id =
        Repo.one!(
          from(sf in SlideFlag,
            where: sf.type == :distinction,
            select: sf.slide_id,
            limit: 1
          )
        )

      {:ok, slide_before} = Slides.get(distinction_slide_id)
      refute slide_before.status == :discarded

      {:ok, view, _} = live(conn, ~p"/organize/#{competition.id}/validation_launcher")

      row = validation_detail_row(distinction_slide_id)

      assert {:error, {:live_redirect, %{to: redirect_to}}} =
               view
               |> element("#{row} a[phx-click=\"move-slide-to-discarded\"]")
               |> render_click()

      assert redirect_to == launcher_path(competition.id)

      {:ok, slide_after} = Slides.get(distinction_slide_id)
      assert slide_after.status == :discarded
    end

    test "clear-all-flags succeeds", %{conn: conn, competition: competition} do
      slide_with_note_id =
        Repo.one!(
          from(sf in SlideFlag,
            where: sf.type == :note,
            select: sf.slide_id,
            limit: 1
          )
        )

      {:ok, slide_before} = Slides.get(slide_with_note_id)
      assert slide_before.slide_flags != []

      {:ok, view, _} = live(conn, ~p"/organize/#{competition.id}/validation_launcher")

      row = validation_detail_row(slide_with_note_id)

      assert {:error, {:live_redirect, %{to: redirect_to}}} =
               view
               |> element("#{row} a[phx-click=\"clear-all-flags\"]")
               |> render_click()

      assert redirect_to == launcher_path(competition.id)

      {:ok, slide_after} = Slides.get(slide_with_note_id)
      assert slide_after.slide_flags == []
    end
  end
end
