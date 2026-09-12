defmodule SMWeb.Live.JuryTest do
  use SMWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.Competitions
  alias SM.Evaluations
  alias SM.Jurors
  alias SM.Repo
  alias SM.Slides
  alias SM.Slides.Slide
  alias SM.Slides.SlideEvaluation
  alias SM.Subjects

  @fixtures_setup [
    :register_and_log_in_user,
    :create_organization,
    :create_competition,
    :create_category,
    :register_users,
    :enroll_participants,
    :enroll_three_jurors,
    :create_slides,
    :seed_subjects_for_selection,
    :select_slides
  ]

  defp seed_subjects_for_selection(_context) do
    base = System.unique_integer([:positive])

    for n <- 1..8 do
      {:ok, _} =
        Subjects.create(%{
          "name" => "Jury test subject #{base}-#{n}",
          "numeric_id" => base * 100 + n,
          "type" => :fish,
          "coefficient" => 1
        })
    end

    :ok
  end

  defp enroll_three_jurors(%{competition: competition, users: users}) do
    jurors =
      users
      |> Enum.take(-3)
      |> Enum.map(fn user ->
        {:ok, juror} = Jurors.create(%{user_id: user.id, competition_id: competition.id})
        juror
      end)

    %{jurors: jurors}
  end

  defp jury_slide_id(%{competition: competition}) do
    jury_slide =
      Repo.one!(
        from(s in Slide,
          where: s.competition_id == ^competition.id and s.status == :submitted_jury,
          limit: 1
        )
      )

    %{jury_slide: jury_slide}
  end

  defp jury_path(competition_id, slide_id) do
    "/organize/#{competition_id}/jury?category=all&slide_id=#{slide_id}"
  end

  defp evaluation_button(competition) do
    evaluation = List.first(competition.allowed_evaluations)
    "#evaluate-#{evaluation.id}"
  end

  defp setup_penalty_evaluation(%{competition: competition}) do
    {:ok, competition} = Competitions.get(competition.id)

    {:ok, penalty_evaluation} =
      Evaluations.create(%{
        "name" => "P",
        "value" => 0,
        "is_penalty" => true,
        "type" => "boolean",
        "description" => "Penalty"
      })

    allowed_evaluations = competition.allowed_evaluations ++ [penalty_evaluation]

    {:ok, competition} =
      Competitions.update_allowed_evaluations(competition.id, allowed_evaluations)

    %{competition: competition, penalty_evaluation: penalty_evaluation}
  end

  describe "penalty and clear workflow" do
    setup @fixtures_setup ++ [:jury_slide_id]

    setup %{competition: competition} do
      {:ok, competition} = Competitions.get(competition.id)
      %{competition: competition}
    end

    test "allows voting again after penalty and clear", %{
      conn: conn,
      competition: competition,
      jury_slide: slide
    } do
      evaluation = List.first(competition.allowed_evaluations)
      {:ok, view, html} = live(conn, jury_path(competition.id, slide.id))

      assert html =~ "phx-value-evaluation-id=\"#{evaluation.id}\""
      refute html =~ "phx-value-{@click_key}"

      refute has_element?(view, "#jury-evaluation-buttons.btn-disabled")

      view |> element("#penalty") |> render_click()
      assert {:ok, penalized_slide} = Slides.get(slide.id)
      assert penalized_slide.penalty
      assert penalized_slide.votes == []
      assert has_element?(view, "#jury-penalty-indicator")

      view |> element("#clear-evaluations") |> render_click()

      refute has_element?(view, "#jury-evaluation-buttons.btn-disabled")

      view |> element(evaluation_button(competition)) |> render_click()

      votes =
        Repo.all(
          from(se in SlideEvaluation,
            where: se.slide_id == ^slide.id,
            preload: :evaluation
          )
        )

      assert length(votes) == 1
      assert List.first(votes).evaluation_id == List.first(competition.allowed_evaluations).id
    end

    test "disables evaluation buttons when every juror has voted", %{
      conn: conn,
      competition: competition,
      jury_slide: slide,
      jurors: jurors
    } do
      evaluation_id = List.first(competition.allowed_evaluations).id

      for juror <- jurors do
        assert :ok =
                 Slides.evaluate_by_juror(competition.id, slide.id, juror.user_id, evaluation_id)
      end

      {:ok, view, _html} = live(conn, jury_path(competition.id, slide.id))

      assert has_element?(view, "#jury-evaluation-buttons.btn-disabled")
    end

    test "allows voting again after clearing a full jury ballot", %{
      conn: conn,
      competition: competition,
      jury_slide: slide,
      jurors: jurors
    } do
      evaluation_id = List.first(competition.allowed_evaluations).id

      for juror <- jurors do
        assert :ok =
                 Slides.evaluate_by_juror(competition.id, slide.id, juror.user_id, evaluation_id)
      end

      {:ok, view, _html} = live(conn, jury_path(competition.id, slide.id))
      assert has_element?(view, "#jury-evaluation-buttons.btn-disabled")

      view |> element("#clear-evaluations") |> render_click()

      refute has_element?(view, "#jury-evaluation-buttons.btn-disabled")

      view |> element(evaluation_button(competition)) |> render_click()

      assert 1 ==
               Repo.aggregate(
                 from(se in SlideEvaluation, where: se.slide_id == ^slide.id),
                 :count
               )
    end
  end

  describe "penalty quorum" do
    setup @fixtures_setup ++ [:jury_slide_id, :setup_penalty_evaluation]

    setup %{competition: competition} do
      {:ok, competition} = Competitions.get(competition.id)
      %{competition: competition}
    end

    test "applies penalty when all enrolled jurors vote P", %{
      competition: competition,
      jury_slide: slide,
      jurors: jurors,
      penalty_evaluation: penalty_evaluation
    } do
      for juror <- jurors do
        assert :ok =
                 Slides.evaluate_by_juror(
                   competition.id,
                   slide.id,
                   juror.user_id,
                   penalty_evaluation.id
                 )
      end

      assert Slides.has_penalty?(slide.id)
    end

    test "applies penalty when all enrolled jurors vote P even if configured jury size is larger", %{
      competition: competition,
      jury_slide: slide,
      jurors: jurors,
      penalty_evaluation: penalty_evaluation
    } do
      settings = competition.settings

      {:ok, competition} =
        Competitions.update(competition, %{
          "settings" => %{
            "number_of_jurors" => 7,
            "evaluations_per_juror" => settings.evaluations_per_juror,
            "max_jury_slides" => settings.max_jury_slides,
            "max_submitted_slides" => settings.max_submitted_slides,
            "proportional_submission" => settings.proportional_submission,
            "submission_ratio" => settings.submission_ratio,
            "fixed_points_multiplier" => settings.fixed_points_multiplier,
            "submission_bonus_per_slide" => settings.submission_bonus_per_slide,
            "penalty_amount" => settings.penalty_amount,
            "coefficient_mode" => settings.coefficient_mode,
            "dynamic_coefficient_mode" => settings.dynamic_coefficient_mode
          }
        })

      for juror <- jurors do
        assert :ok =
                 Slides.evaluate_by_juror(
                   competition.id,
                   slide.id,
                   juror.user_id,
                   penalty_evaluation.id
                 )
      end

      assert Slides.has_penalty?(slide.id)
    end

    test "shows penalty indicator after quorum penalty votes from the jury UI", %{
      conn: conn,
      competition: competition,
      jury_slide: slide,
      jurors: jurors,
      penalty_evaluation: penalty_evaluation
    } do
      for juror <- jurors do
        assert :ok =
                 Slides.evaluate_by_juror(
                   competition.id,
                   slide.id,
                   juror.user_id,
                   penalty_evaluation.id
                 )
      end

      {:ok, view, _html} = live(conn, jury_path(competition.id, slide.id))

      html = render(view)

      assert has_element?(view, "#jury-penalty-indicator")
      assert html =~ "Evaluations"
      assert html =~ "P"
    end
  end

end
