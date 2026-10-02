defmodule SM.Slides.SubjectsDistributionTest do
  @moduledoc """
  Regression coverage for dynamic-coefficient subject distribution.

  Distribution must count distinct competing entities (participants or teams),
  not raw slide rows or individual team members.
  """

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

  describe "subjects_distribution/1 for team competitions" do
    test "counts distinct teams so a subject captured by every team is 100%" do
      ctx = base_setup(for_teams: true)
      competition = enable_dynamic_fixed!(ctx.competition)

      {team_a_users, team_b_users} = enroll_two_teams(ctx, competition)

      n = System.unique_integer([:positive])

      {:ok, subject_common} =
        Subjects.create(%{
          "name" => "Common fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 1,
          "scientific_name" => "Communis teamus"
        })

      {:ok, subject_filler} =
        Subjects.create(%{
          "name" => "Filler fish #{n}",
          "numeric_id" => n + 1,
          "type" => :fish,
          "coefficient" => 1,
          "scientific_name" => "Fillerus teamus"
        })

      # One member per team captures the common subject; the other member
      # still submits a different species so all four participants are active.
      [a1, a2] = team_a_users
      [b1, b2] = team_b_users

      create_submitted_slide!(competition, a1, "a1-common.jpg", subject_common.id)
      create_submitted_slide!(competition, a2, "a2-filler.jpg", subject_filler.id)
      create_submitted_slide!(competition, b1, "b1-common.jpg", subject_common.id)
      create_submitted_slide!(competition, b2, "b2-filler.jpg", subject_filler.id)

      common =
        competition.id
        |> Subjects.list_with_coefficients()
        |> Enum.find(&(&1.id == subject_common.id))

      assert common.count == 2
      assert Decimal.eq?(common.distribution, Decimal.new("1.0"))
      assert Decimal.eq?(common.dynamic_coefficient, Decimal.new(1))

      assert {:ok, team_results} = Results.list_for_teams(competition.id)

      common_coeffs =
        team_results
        |> Enum.flat_map(& &1.slides)
        |> Enum.filter(&(&1.slide.subject_id == subject_common.id))
        |> Enum.map(& &1.coefficient)

      assert length(common_coeffs) == 2
      assert Enum.all?(common_coeffs, &Decimal.eq?(&1, Decimal.new(2)))
    end

    test "counts a team once when multiple members submit the same subject" do
      ctx = base_setup(for_teams: true)
      competition = enable_dynamic_fixed!(ctx.competition)

      {[a1, a2], [b1, b2]} = enroll_two_teams(ctx, competition)

      n = System.unique_integer([:positive])

      {:ok, subject_common} =
        Subjects.create(%{
          "name" => "Dup team fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 1,
          "scientific_name" => "Duplus teamus"
        })

      {:ok, subject_rare} =
        Subjects.create(%{
          "name" => "Rare team fish #{n}",
          "numeric_id" => n + 1,
          "type" => :fish,
          "coefficient" => 1,
          "scientific_name" => "Rarus teamus"
        })

      # Team A: both members submit the common subject (still one team)
      create_submitted_slide!(competition, a1, "a1.jpg", subject_common.id)
      create_submitted_slide!(competition, a2, "a2.jpg", subject_common.id)
      # Team B: one common + one rare
      create_submitted_slide!(competition, b1, "b1.jpg", subject_common.id)
      create_submitted_slide!(competition, b2, "b2.jpg", subject_rare.id)

      subjects =
        competition.id
        |> Subjects.list_with_coefficients()
        |> Map.new(&{&1.id, &1})

      common = Map.fetch!(subjects, subject_common.id)
      rare = Map.fetch!(subjects, subject_rare.id)

      assert common.count == 2
      assert Decimal.eq?(common.distribution, Decimal.new("1.0"))
      assert Decimal.eq?(common.dynamic_coefficient, Decimal.new(1))

      assert rare.count == 1
      assert Decimal.eq?(rare.distribution, Decimal.new("0.5"))
      assert Decimal.eq?(rare.dynamic_coefficient, Decimal.new(2))
    end
  end

  describe "subjects_distribution/1 for individual competitions" do
    test "counts distinct participants and ignores discarded-only users" do
      ctx = base_setup(for_teams: false)
      competition = enable_dynamic_fixed!(ctx.competition)

      users =
        for i <- 1..3 do
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
              number: i
            })

          user
        end

      [u1, u2, u3] = users

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Solo fish #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 1,
          "scientific_name" => "Solus testus"
        })

      # u1 submits two slides of the same subject → still one participant
      create_submitted_slide!(competition, u1, "u1-a.jpg", subject.id)
      create_submitted_slide!(competition, u1, "u1-b.jpg", subject.id)
      create_submitted_slide!(competition, u2, "u2.jpg", subject.id)

      # u3 only has a discarded slide → must not enter the denominator
      {:ok, discarded} =
        Slides.create(%{
          user_id: u3.id,
          competition_id: competition.id,
          file_name: "u3-discarded.jpg",
          file_size: 1000
        })

      {:ok, _discarded} = Slides.update(discarded, %{subject_id: subject.id, status: :discarded})

      row =
        competition.id
        |> Subjects.list_with_coefficients()
        |> Enum.find(&(&1.id == subject.id))

      assert row.count == 2
      assert Decimal.eq?(row.distribution, Decimal.new("1.0"))
      assert Decimal.eq?(row.dynamic_coefficient, Decimal.new(1))
    end
  end

  defp base_setup(opts) do
    for_teams = Keyword.fetch!(opts, :for_teams)

    {:ok, organization} = Organizations.create(%{"name" => "Dist Org", "location" => "Here"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 5,
        "name" => "Five"
      })

    {:ok, competition} =
      Competitions.create(%{
        "name" => "Dist Cup #{System.unique_integer([:positive])}",
        "type" => :qualification,
        "organization_id" => organization.id,
        "for_teams" => for_teams,
        "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
      })

    {:ok, category} = Categories.create(%{"name" => "Dist Cat", "camera_type" => :reflex})
    {:ok, competition} = Competitions.get(competition.id)

    %{
      organization: organization,
      competition: competition,
      category: category
    }
  end

  defp enable_dynamic_fixed!(competition) do
    attrs = %{
      "coefficient_mode" => "disabled",
      "dynamic_coefficient_mode" => "submitted_fixed",
      "dynamic_coefficients" => [
        %{"name" => "tier_common", "from" => "0.66", "to" => "1.0", "value" => "1"},
        %{"name" => "tier_mid", "from" => "0.33", "to" => "0.66", "value" => "2"},
        %{"name" => "tier_rare", "from" => "0", "to" => "0.33", "value" => "3"}
      ]
    }

    {:ok, _settings} =
      competition.settings
      |> CompetitionSettings.changeset(attrs)
      |> Repo.update()

    {:ok, c} = Competitions.get(competition.id)
    c
  end

  defp enroll_two_teams(ctx, competition) do
    users =
      for i <- 1..4 do
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
            number: i
          })

        user
      end

    [a1, a2, b1, b2] = users

    {:ok, _team_a} =
      Teams.create(%{
        "competition_id" => competition.id,
        "number" => 1,
        "name" => "Team A",
        "members" => [%{"user_id" => a1.id}, %{"user_id" => a2.id}]
      })

    {:ok, _team_b} =
      Teams.create(%{
        "competition_id" => competition.id,
        "number" => 2,
        "name" => "Team B",
        "members" => [%{"user_id" => b1.id}, %{"user_id" => b2.id}]
      })

    {[a1, a2], [b1, b2]}
  end

  defp create_submitted_slide!(competition, user, file_name, subject_id) do
    {:ok, slide} =
      Slides.create(%{
        user_id: user.id,
        competition_id: competition.id,
        file_name: file_name,
        file_size: 1000
      })

    {:ok, slide} = Slides.update(slide, %{subject_id: subject_id, status: :submitted_fixed})
    slide
  end
end
