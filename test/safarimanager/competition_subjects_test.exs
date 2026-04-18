defmodule SM.CompetitionSubjectsTest do
  use SM.DataCase, async: true

  alias SM.AccountsFixtures
  alias SM.Categories
  alias SM.Competitions
  alias SM.Evaluations
  alias SM.Organizations
  alias SM.Participants
  alias SM.Repo
  alias SM.Results
  alias SM.Slides
  alias SM.Subjects

  defp minimal_competition!(organization_id, evaluation_id, competition_subjects) do
    attrs = %{
      "name" => "CS test #{System.unique_integer([:positive])}",
      "type" => :qualification,
      "organization_id" => organization_id,
      "competitions_evaluations" => [%{"evaluation_id" => evaluation_id}],
      "competition_subjects" => competition_subjects
    }

    {:ok, c} = Competitions.create(attrs)
    c
  end

  test "Results.list uses per-competition static coefficient when competition_subjects exist" do
    {:ok, organization} = Organizations.create(%{"name" => "CS Org", "location" => "X"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 5,
        "name" => "Five"
      })

    n = System.unique_integer([:positive])

    {:ok, subject} =
      Subjects.create(%{
        "name" => "CS fish #{n}",
        "numeric_id" => n,
        "type" => :fish,
        "coefficient" => 2,
        "scientific_name" => "Testus sp."
      })

    competition =
      minimal_competition!(organization.id, evaluation.id, %{
        "0" => %{"subject_id" => subject.id, "coefficient" => 7}
      })

    {:ok, category} = Categories.create(%{"name" => "Cat", "camera_type" => :reflex})

    user =
      AccountsFixtures.competition_user_fixture(%{
        organization_id: organization.id,
        category_id: category.id
      })

    {:ok, _participant} =
      Participants.create(%{
        user_id: user.id,
        competition_id: competition.id,
        category_id: category.id,
        number: 1
      })

    {:ok, slide} =
      Slides.create(%{
        user_id: user.id,
        competition_id: competition.id,
        file_name: "x.jpg",
        file_size: 100
      })

    {:ok, _updated_slide} =
      Slides.update(slide, %{subject_id: subject.id, status: :submitted_fixed})

    assert {:ok, [result]} = Results.list(competition.id, nil)
    # default fixed_points_multiplier 5 × effective coefficient 7 = 35 (not 2 → 10)
    assert Decimal.eq?(result.slide_points, Decimal.new(35))
    assert Decimal.eq?(result.submission_bonus, Decimal.new(0))
    assert Decimal.eq?(result.total_score, Decimal.new(35))
  end

  test "Competitions.duplicate copies competition_subjects rows" do
    {:ok, organization} = Organizations.create(%{"name" => "Dup Org", "location" => "Y"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 0,
        "name" => "0"
      })

    n = System.unique_integer([:positive])

    {:ok, subject} =
      Subjects.create(%{
        "name" => "Dup fish #{n}",
        "numeric_id" => n,
        "type" => :fish,
        "coefficient" => 1
      })

    {:ok, source} =
      Competitions.create(%{
        "name" => "Source comp",
        "type" => :qualification,
        "organization_id" => organization.id,
        "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}],
        "competition_subjects" => %{"0" => %{"subject_id" => subject.id, "coefficient" => 42}}
      })

    assert {:ok, dup} =
             Competitions.duplicate(source.id, %{
               "new_competition_name" => "Dup comp",
               "new_for_teams" => "false",
               "for_teams" => "false",
               "participants" => "false",
               "teams" => "false",
               "jurors" => "false",
               "slides" => "false",
               "selection" => "false",
               "votes" => "false"
             })

    dup = Repo.preload(dup, :competition_subjects)
    assert length(dup.competition_subjects) == 1
    row = hd(dup.competition_subjects)
    assert row.subject_id == subject.id
    assert row.coefficient == 42
  end

  test "bulk_set_competition_subject_params sets every row to the same coefficient (>= 0)" do
    nested = %{
      "0" => %{"subject_id" => "a", "coefficient" => 3},
      "1" => %{"subject_id" => "b", "coefficient" => 7}
    }

    assert Competitions.bulk_set_competition_subject_params(nested, 5) == %{
             "0" => %{"subject_id" => "a", "coefficient" => 5},
             "1" => %{"subject_id" => "b", "coefficient" => 5}
           }

    assert Competitions.bulk_set_competition_subject_params(nested, -2) == %{
             "0" => %{"subject_id" => "a", "coefficient" => 0},
             "1" => %{"subject_id" => "b", "coefficient" => 0}
           }
  end
end
