defmodule SM.ResultsSubmissionBonusTest do
  use SM.DataCase, async: false

  alias SM.AccountsFixtures
  alias SM.Categories
  alias SM.Competitions
  alias SM.Competitions.CompetitionSettings
  alias SM.Evaluations
  alias SM.Organizations
  alias SM.Participants
  alias SM.Repo
  alias SM.Results
  alias SM.Slides
  alias SM.Subjects
  alias SM.Teams

  defp base_setup do
    {:ok, organization} = Organizations.create(%{"name" => "Bonus Org", "location" => "Here"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 5,
        "name" => "Five"
      })

    {:ok, competition} =
      Competitions.create(%{
        "name" => "Bonus Cup #{System.unique_integer([:positive])}",
        "type" => :qualification,
        "organization_id" => organization.id,
        "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
      })

    {:ok, category} = Categories.create(%{"name" => "Test Cat", "camera_type" => :reflex})

    {:ok, competition} = Competitions.get(competition.id)

    %{
      organization: organization,
      evaluation: evaluation,
      competition: competition,
      category: category
    }
  end

  defp set_submission_bonus!(competition, %Decimal{} = value) do
    {:ok, _} =
      competition.settings
      |> CompetitionSettings.changeset(%{"submission_bonus_per_slide" => value})
      |> Repo.update()

    {:ok, c} = Competitions.get(competition.id)
    c
  end

  describe "submission_bonus_per_slide" do
    test "k=0 leaves totals equal to slide points only" do
      ctx = base_setup()
      competition = ctx.competition

      user =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: ctx.organization.id,
          category_id: ctx.category.id
        })

      {:ok, _participant} =
        Participants.create(%{
          user_id: user.id,
          competition_id: competition.id,
          category_id: ctx.category.id,
          number: 1
        })

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 2,
          "scientific_name" => "Testus bonus"
        })

      {:ok, slide} =
        Slides.create(%{
          user_id: user.id,
          competition_id: competition.id,
          file_name: "a.jpg",
          file_size: 1000
        })

      {:ok, _} = Slides.update(slide, %{subject_id: subject.id, status: :submitted_fixed})

      assert {:ok, [result]} = Results.list(competition.id, nil)
      assert Decimal.eq?(result.slide_points, Decimal.new(10))
      assert Decimal.eq?(result.submission_bonus, Decimal.new(0))
      assert Decimal.eq?(result.total_score, Decimal.new(10))
    end

    test "adds k × N when no penalties" do
      ctx = base_setup()
      competition = set_submission_bonus!(ctx.competition, Decimal.new(5))

      user =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: ctx.organization.id,
          category_id: ctx.category.id
        })

      {:ok, _participant} =
        Participants.create(%{
          user_id: user.id,
          competition_id: competition.id,
          category_id: ctx.category.id,
          number: 1
        })

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 2,
          "scientific_name" => "Testus bonus"
        })

      for {name, i} <- [{"a.jpg", 1}, {"b.jpg", 2}] do
        {:ok, slide} =
          Slides.create(%{
            user_id: user.id,
            competition_id: competition.id,
            file_name: name,
            file_size: 1000 + i
          })

        {:ok, _} = Slides.update(slide, %{subject_id: subject.id, status: :submitted_fixed})
      end

      assert {:ok, [result]} = Results.list(competition.id, nil)
      # two slides × (2 × 5) = 20 slide points; bonus 5 × 2 = 10
      assert Decimal.eq?(result.slide_points, Decimal.new(20))
      assert Decimal.eq?(result.submission_bonus, Decimal.new(10))
      assert Decimal.eq?(result.total_score, Decimal.new(30))
    end

    test "forfeits entire bonus when any slide is penalised" do
      ctx = base_setup()
      competition = set_submission_bonus!(ctx.competition, Decimal.new(5))

      user =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: ctx.organization.id,
          category_id: ctx.category.id
        })

      {:ok, _participant} =
        Participants.create(%{
          user_id: user.id,
          competition_id: competition.id,
          category_id: ctx.category.id,
          number: 1
        })

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 2,
          "scientific_name" => "Testus bonus"
        })

      {:ok, slide} =
        Slides.create(%{
          user_id: user.id,
          competition_id: competition.id,
          file_name: "pen.jpg",
          file_size: 1000
        })

      {:ok, slide} =
        Slides.update(slide, %{
          subject_id: subject.id,
          status: :submitted_jury,
          penalty: true
        })

      assert slide.penalty == true

      assert {:ok, [result]} = Results.list(competition.id, nil)
      assert Decimal.eq?(result.submission_bonus, Decimal.new(0))
      assert Decimal.eq?(result.slide_points, competition.settings.penalty_amount)
      assert Decimal.eq?(result.total_score, competition.settings.penalty_amount)
    end

    test "team: single bonus k × total slides across members" do
      ctx = base_setup()

      {:ok, competition} =
        Competitions.update(ctx.competition, %{
          "for_teams" => true
        })

      competition = set_submission_bonus!(competition, Decimal.new(3))

      user_a =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: ctx.organization.id,
          category_id: ctx.category.id
        })

      user_b =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: ctx.organization.id,
          category_id: ctx.category.id
        })

      for {user, num} <- [{user_a, 1}, {user_b, 2}] do
        {:ok, _} =
          Participants.create(%{
            user_id: user.id,
            competition_id: competition.id,
            category_id: ctx.category.id,
            number: num
          })
      end

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 2,
          "scientific_name" => "Testus team"
        })

      for {user, fname} <- [{user_a, "a.jpg"}, {user_b, "b.jpg"}] do
        {:ok, slide} =
          Slides.create(%{
            user_id: user.id,
            competition_id: competition.id,
            file_name: fname,
            file_size: 1000
          })

        {:ok, _} = Slides.update(slide, %{subject_id: subject.id, status: :submitted_fixed})
      end

      {:ok, team} =
        Teams.create(%{
          "competition_id" => competition.id,
          "number" => 1,
          "name" => "Team T",
          "members" => [
            %{"user_id" => user_a.id},
            %{"user_id" => user_b.id}
          ]
        })

      assert team.id

      assert {:ok, [result]} = Results.list_for_teams(competition.id)
      assert Decimal.eq?(result.slide_points, Decimal.new(20))
      assert Decimal.eq?(result.submission_bonus, Decimal.new(6))
      assert Decimal.eq?(result.total_score, Decimal.new(26))
    end

    test "team: zero bonus when any member slide is penalised" do
      ctx = base_setup()

      {:ok, competition} =
        Competitions.update(ctx.competition, %{
          "for_teams" => true
        })

      competition = set_submission_bonus!(competition, Decimal.new(3))

      user_a =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: ctx.organization.id,
          category_id: ctx.category.id
        })

      user_b =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: ctx.organization.id,
          category_id: ctx.category.id
        })

      for {user, num} <- [{user_a, 1}, {user_b, 2}] do
        {:ok, _} =
          Participants.create(%{
            user_id: user.id,
            competition_id: competition.id,
            category_id: ctx.category.id,
            number: num
          })
      end

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 2,
          "scientific_name" => "Testus team"
        })

      {:ok, slide_a} =
        Slides.create(%{
          user_id: user_a.id,
          competition_id: competition.id,
          file_name: "ok.jpg",
          file_size: 1000
        })

      {:ok, _} =
        Slides.update(slide_a, %{subject_id: subject.id, status: :submitted_fixed})

      {:ok, slide_b} =
        Slides.create(%{
          user_id: user_b.id,
          competition_id: competition.id,
          file_name: "bad.jpg",
          file_size: 1001
        })

      {:ok, _} =
        Slides.update(slide_b, %{
          subject_id: subject.id,
          status: :submitted_jury,
          penalty: true
        })

      {:ok, _} =
        Teams.create(%{
          "competition_id" => competition.id,
          "number" => 1,
          "name" => "Team P",
          "members" => [
            %{"user_id" => user_a.id},
            %{"user_id" => user_b.id}
          ]
        })

      assert {:ok, [result]} = Results.list_for_teams(competition.id)
      assert Decimal.eq?(result.submission_bonus, Decimal.new(0))
      assert Decimal.compare(result.total_score, Decimal.new(0)) == :lt
    end
  end

  describe "CompetitionSettings changeset" do
    test "rejects negative submission_bonus_per_slide" do
      cs =
        CompetitionSettings.changeset(%CompetitionSettings{}, %{
          "evaluations_per_juror" => 1,
          "number_of_jurors" => 3,
          "max_jury_slides" => 15,
          "max_submitted_slides" => 99,
          "submission_ratio" => "0.25",
          "fixed_points_multiplier" => "5.0",
          "submission_bonus_per_slide" => "-1",
          "penalty_amount" => "-100"
        })

      refute cs.valid?
    end
  end
end
