defmodule SM.ResultsLegacyScoringTest do
  @moduledoc """
  Characterization tests for legacy scoring (no `competition_subjects` rows).

  Locks in behavior before per-competition coefficients; legacy mode must keep matching these.
  """

  use SM.DataCase, async: true

  alias SM.AccountsFixtures
  alias SM.Categories
  alias SM.Competitions
  alias SM.Evaluations
  alias SM.Organizations
  alias SM.Participants
  alias SM.Results
  alias SM.Slides
  alias SM.Subjects

  setup do
    {:ok, organization} = Organizations.create(%{"name" => "Test Org", "location" => "Here"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 5,
        "name" => "Five"
      })

    {:ok, competition} =
      Competitions.create(%{
        "name" => "Legacy Scoring Cup",
        "type" => :qualification,
        "organization_id" => organization.id,
        "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
      })

    {:ok, category} = Categories.create(%{"name" => "Test Cat", "camera_type" => :reflex})

    user =
      AccountsFixtures.competition_user_fixture(%{
        organization_id: organization.id,
        category_id: category.id
      })

    {:ok, participant} =
      Participants.create(%{
        user_id: user.id,
        competition_id: competition.id,
        category_id: category.id,
        number: 1
      })

    numeric_id = System.unique_integer([:positive])

    {:ok, subject} =
      Subjects.create(%{
        "name" => "Legacy Test Fish #{numeric_id}",
        "numeric_id" => numeric_id,
        "type" => :fish,
        "coefficient" => 2,
        "scientific_name" => "Testus legacyus"
      })

    {:ok, slide} =
      Slides.create(%{
        user_id: user.id,
        competition_id: competition.id,
        file_name: "legacy.jpg",
        file_size: 1000
      })

    {:ok, slide} =
      Slides.update(slide, %{subject_id: subject.id, status: :submitted_fixed})

    %{
      competition: competition,
      participant: participant,
      subject: subject,
      slide: slide,
      user: user
    }
  end

  describe "legacy mode (no competition_subjects)" do
    test "Results.list uses global subject coefficient for submitted_fixed", %{
      competition: competition,
      subject: subject
    } do
      {:ok, competition} = Competitions.get(competition.id)
      # Default settings: coefficient_mode :all, dynamic disabled, fixed_points_multiplier 5.0
      assert Decimal.eq?(
               competition.settings.fixed_points_multiplier,
               Decimal.new("5.0")
             )

      assert {:ok, [result]} = Results.list(competition.id, nil)
      assert result.slides_count == 1
      [row] = result.slides
      assert row.slide.subject_id == subject.id
      # coefficient from subject (2) × fixed_points_multiplier (5) = 10
      assert Decimal.eq?(row.slide_score, Decimal.new(10))
      assert Decimal.eq?(row.coefficient, Decimal.new(2))
      assert Decimal.eq?(result.total_score, Decimal.new(10))
    end

    test "Subjects.list_with_coefficients uses global static coefficient", %{
      competition: competition,
      subject: subject
    } do
      subjects = Subjects.list_with_coefficients(competition.id)
      assert length(subjects) == 1
      [s] = subjects
      assert s.id == subject.id
      assert s.coefficient == 2
      assert s.dynamic_coefficient == Decimal.new("1")
    end
  end
end
