defmodule SM.ResultsTeamDuplicatesTest do
  @moduledoc """
  Investigates whether team results can list the same slide (or subject) twice.

  `Results.list_for_teams/1` concatenates each member's scoring slides with no
  de-duplication by slide id or subject. Unique slide ids should never repeat
  under normal membership constraints; the same subject can appear twice when
  two teammates each submit it.
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
  alias SM.Teams

  describe "list_for_teams/1 uniqueness" do
    test "with unique subjects across teammates, results never invent slide or subject duplicates" do
      ctx = setup_team_competition!()
      {[a1, a2], [b1, b2]} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      s1 = create_subject!(n, "Fish A")
      s2 = create_subject!(n + 1, "Fish B")
      s3 = create_subject!(n + 2, "Fish C")
      s4 = create_subject!(n + 3, "Fish D")

      slide_a1 = create_slide!(ctx.competition, a1, "a1.jpg", s1.id, :submitted_fixed)
      slide_a2 = create_slide!(ctx.competition, a2, "a2.jpg", s2.id, :submitted_jury)
      _b1 = create_slide!(ctx.competition, b1, "b1.jpg", s3.id, :submitted_fixed)
      _b2 = create_slide!(ctx.competition, b2, "b2.jpg", s4.id, :submitted_fixed)

      # DB ground truth for team A: unique subjects among scoring slides
      team_a_record =
        ctx.competition.id
        |> Teams.list_by_competition()
        |> Enum.find(&(&1.number == 1))

      team_a_db_subjects =
        team_a_record.id
        |> Slides.list_by_team(ctx.competition.id)
        |> Enum.filter(&(&1.status in [:submitted_fixed, :submitted_jury]))
        |> Enum.map(& &1.subject_id)

      assert length(team_a_db_subjects) == length(Enum.uniq(team_a_db_subjects))

      assert {:ok, results} = Results.list_for_teams(ctx.competition.id)
      team_a = Enum.find(results, &(&1.team.number == 1))

      slide_ids = Enum.map(team_a.slides, & &1.slide.id)
      subject_ids = Enum.map(team_a.slides, & &1.slide.subject_id)

      assert Enum.sort(slide_ids) == Enum.sort([slide_a1.id, slide_a2.id])
      assert length(slide_ids) == length(Enum.uniq(slide_ids))
      assert length(subject_ids) == length(Enum.uniq(subject_ids))
      assert Enum.sort(subject_ids) == Enum.sort([s1.id, s2.id])
    end

    test "many votes on one jury slide still yield a single result row" do
      ctx = setup_team_competition!()
      {[a1, a2], _team_b} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Voted fish")
      filler = create_subject!(n + 1, "Filler")

      slide = create_slide!(ctx.competition, a1, "jury.jpg", subject.id, :submitted_jury)
      _a2 = create_slide!(ctx.competition, a2, "fixed.jpg", filler.id, :submitted_fixed)

      # Attach several votes; preload must not multiply the slide in results.
      for i <- 1..3 do
        juror =
          AccountsFixtures.competition_user_fixture(%{
            organization_id: ctx.organization.id,
            category_id: ctx.category.id
          })

        {:ok, evaluation} =
          Evaluations.create(%{"value" => i, "name" => "Vote#{i}-#{n}"})

        {:ok, _} =
          Slides.create_slide_evaluation(%{
            "slide_id" => slide.id,
            "user_id" => juror.id,
            "evaluation_id" => evaluation.id
          })
      end

      assert {:ok, results} = Results.list_for_teams(ctx.competition.id)
      team_a = Enum.find(results, &(&1.team.number == 1))

      matching = Enum.filter(team_a.slides, &(&1.slide.id == slide.id))
      assert length(matching) == 1
    end

    test "does not list the same slide id twice for a team" do
      ctx = setup_team_competition!()
      {[a1, a2], _team_b} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Unique slide fish")

      slide_a1 = create_slide!(ctx.competition, a1, "a1-fixed.jpg", subject.id, :submitted_fixed)
      slide_a2 = create_slide!(ctx.competition, a2, "a2-jury.jpg", subject.id, :submitted_jury)

      assert {:ok, results} = Results.list_for_teams(ctx.competition.id)
      team_a = Enum.find(results, &(&1.team.number == 1))

      slide_ids = Enum.map(team_a.slides, & &1.slide.id)

      assert Enum.sort(slide_ids) == Enum.sort([slide_a1.id, slide_a2.id])
      assert length(slide_ids) == length(Enum.uniq(slide_ids))
    end

    test "lists the same subject twice when two teammates each submit it as fixed points" do
      ctx = setup_team_competition!()
      {[a1, a2], [b1, b2]} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Dup subject fixed")
      filler = create_subject!(n + 1, "Filler subject")

      slide_a1 = create_slide!(ctx.competition, a1, "a1.jpg", subject.id, :submitted_fixed)
      slide_a2 = create_slide!(ctx.competition, a2, "a2.jpg", subject.id, :submitted_fixed)
      _b1 = create_slide!(ctx.competition, b1, "b1.jpg", filler.id, :submitted_fixed)
      _b2 = create_slide!(ctx.competition, b2, "b2.jpg", filler.id, :submitted_fixed)

      assert {:ok, results} = Results.list_for_teams(ctx.competition.id)
      team_a = Enum.find(results, &(&1.team.number == 1))

      fixed_rows =
        Enum.filter(team_a.slides, fn row ->
          row.slide.status == :submitted_fixed and row.slide.subject_id == subject.id
        end)

      # Same subject, two distinct slides — both scored for the team.
      assert length(fixed_rows) == 2
      assert Enum.map(fixed_rows, & &1.slide.id) |> Enum.sort() ==
               Enum.sort([slide_a1.id, slide_a2.id])

      assert Enum.all?(fixed_rows, &(&1.slide.subject_id == subject.id))
    end

    test "lists the same subject twice when two teammates each submit it to jury" do
      ctx = setup_team_competition!()
      {[a1, a2], [b1, b2]} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Dup subject jury")
      filler = create_subject!(n + 1, "Filler jury")

      slide_a1 = create_slide!(ctx.competition, a1, "a1-jury.jpg", subject.id, :submitted_jury)
      slide_a2 = create_slide!(ctx.competition, a2, "a2-jury.jpg", subject.id, :submitted_jury)
      _b1 = create_slide!(ctx.competition, b1, "b1-jury.jpg", filler.id, :submitted_jury)
      _b2 = create_slide!(ctx.competition, b2, "b2-jury.jpg", filler.id, :submitted_fixed)

      assert {:ok, results} = Results.list_for_teams(ctx.competition.id)
      team_a = Enum.find(results, &(&1.team.number == 1))

      jury_rows =
        Enum.filter(team_a.slides, fn row ->
          row.slide.status == :submitted_jury and row.slide.subject_id == subject.id
        end)

      assert length(jury_rows) == 2
      assert Enum.map(jury_rows, & &1.slide.id) |> Enum.sort() ==
               Enum.sort([slide_a1.id, slide_a2.id])
    end

    test "lists two slides of the same subject from one member (no de-dupe)" do
      ctx = setup_team_competition!()
      {[a1, a2], _team_b} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Solo dup subject")
      filler = create_subject!(n + 1, "Solo filler")

      slide_1 = create_slide!(ctx.competition, a1, "a1-a.jpg", subject.id, :submitted_fixed)
      slide_2 = create_slide!(ctx.competition, a1, "a1-b.jpg", subject.id, :submitted_fixed)
      _a2 = create_slide!(ctx.competition, a2, "a2.jpg", filler.id, :submitted_fixed)

      assert {:ok, results} = Results.list_for_teams(ctx.competition.id)
      team_a = Enum.find(results, &(&1.team.number == 1))

      same_subject =
        Enum.filter(team_a.slides, &(&1.slide.subject_id == subject.id))

      assert length(same_subject) == 2
      assert Enum.map(same_subject, & &1.slide.id) |> Enum.sort() ==
               Enum.sort([slide_1.id, slide_2.id])
      assert length(Enum.uniq(Enum.map(team_a.slides, & &1.slide.id))) ==
               length(team_a.slides)
    end
  end

  defp setup_team_competition! do
    {:ok, organization} = Organizations.create(%{"name" => "Dup Org", "location" => "Here"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 5,
        "name" => "Five"
      })

    {:ok, competition} =
      Competitions.create(%{
        "name" => "Team Dup Cup #{System.unique_integer([:positive])}",
        "type" => :qualification,
        "organization_id" => organization.id,
        "for_teams" => true,
        "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
      })

    {:ok, category} = Categories.create(%{"name" => "Dup Cat", "camera_type" => :reflex})
    {:ok, competition} = Competitions.get(competition.id)

    %{organization: organization, competition: competition, category: category}
  end

  defp enroll_two_teams!(ctx) do
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
            competition_id: ctx.competition.id,
            category_id: ctx.category.id,
            number: i
          })

        user
      end

    [a1, a2, b1, b2] = users

    {:ok, _team_a} =
      Teams.create(%{
        "competition_id" => ctx.competition.id,
        "number" => 1,
        "name" => "Team A",
        "members" => [%{"user_id" => a1.id}, %{"user_id" => a2.id}]
      })

    {:ok, _team_b} =
      Teams.create(%{
        "competition_id" => ctx.competition.id,
        "number" => 2,
        "name" => "Team B",
        "members" => [%{"user_id" => b1.id}, %{"user_id" => b2.id}]
      })

    {[a1, a2], [b1, b2]}
  end

  defp create_subject!(numeric_id, name) do
    {:ok, subject} =
      Subjects.create(%{
        "name" => "#{name} #{numeric_id}",
        "numeric_id" => numeric_id,
        "type" => :fish,
        "coefficient" => 1,
        "scientific_name" => "Duplus #{numeric_id}"
      })

    subject
  end

  defp create_slide!(competition, user, file_name, subject_id, status) do
    {:ok, slide} =
      Slides.create(%{
        user_id: user.id,
        competition_id: competition.id,
        file_name: file_name,
        file_size: 1000
      })

    {:ok, slide} = Slides.update(slide, %{subject_id: subject_id, status: status})
    slide
  end
end
