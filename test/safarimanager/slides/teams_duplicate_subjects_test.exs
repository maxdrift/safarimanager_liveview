defmodule SM.Slides.TeamsDuplicateSubjectsTest do
  @moduledoc """
  Team validation must flag a subject submitted more than once by the same team,
  whether those slides belong to one member or to different members.
  """

  use SM.DataCase, async: true

  alias SM.AccountsFixtures
  alias SM.Categories
  alias SM.Competitions
  alias SM.Evaluations
  alias SM.Organizations
  alias SM.Participants
  alias SM.Slides
  alias SM.Subjects
  alias SM.Teams

  describe "list_teams_duplicate_subjects/1" do
    test "flags when two teammates each submit the same subject" do
      ctx = setup_team_competition!()
      {[a1, a2], [b1, b2]} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Shared fish")
      other = create_subject!(n + 1, "Other fish")

      slide_a1 = create_slide!(ctx.competition, a1, "a1.jpg", subject.id, :submitted_fixed)
      slide_a2 = create_slide!(ctx.competition, a2, "a2.jpg", subject.id, :submitted_jury)
      _b1 = create_slide!(ctx.competition, b1, "b1.jpg", other.id, :submitted_fixed)
      _b2 = create_slide!(ctx.competition, b2, "b2.jpg", subject.id, :submitted_fixed)

      rows = Slides.list_teams_duplicate_subjects(ctx.competition.id)

      assert length(rows) == 2
      assert Enum.all?(rows, fn {team_number, _participant_number, _slide} -> team_number == 1 end)

      slide_ids = Enum.map(rows, fn {_t, _p, slide} -> slide.id end)
      assert Enum.sort(slide_ids) == Enum.sort([slide_a1.id, slide_a2.id])
      assert Enum.all?(rows, fn {_t, _p, slide} -> slide.subject_id == subject.id end)
    end

    test "flags when one teammate submits the same subject twice" do
      ctx = setup_team_competition!()
      {[a1, a2], _team_b} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Solo dup fish")
      filler = create_subject!(n + 1, "Filler fish")

      slide_1 = create_slide!(ctx.competition, a1, "a1-a.jpg", subject.id, :submitted_fixed)
      slide_2 = create_slide!(ctx.competition, a1, "a1-b.jpg", subject.id, :submitted_fixed)
      _a2 = create_slide!(ctx.competition, a2, "a2.jpg", filler.id, :submitted_fixed)

      rows = Slides.list_teams_duplicate_subjects(ctx.competition.id)

      assert length(rows) == 2
      slide_ids = Enum.map(rows, fn {_t, _p, slide} -> slide.id end)
      assert Enum.sort(slide_ids) == Enum.sort([slide_1.id, slide_2.id])
    end

    test "ignores discarded slides and unique subjects" do
      ctx = setup_team_competition!()
      {[a1, a2], _team_b} = enroll_two_teams!(ctx)

      n = System.unique_integer([:positive])
      subject = create_subject!(n, "Unique fish")
      other = create_subject!(n + 1, "Also unique")

      _a1 = create_slide!(ctx.competition, a1, "a1.jpg", subject.id, :submitted_fixed)
      _a2 = create_slide!(ctx.competition, a2, "a2.jpg", other.id, :submitted_fixed)

      {:ok, discarded} =
        Slides.create(%{
          user_id: a2.id,
          competition_id: ctx.competition.id,
          file_name: "a2-discarded.jpg",
          file_size: 1000
        })

      {:ok, _} = Slides.update(discarded, %{subject_id: subject.id, status: :discarded})

      assert Slides.list_teams_duplicate_subjects(ctx.competition.id) == []
    end
  end

  defp setup_team_competition! do
    {:ok, organization} = Organizations.create(%{"name" => "Dup Val Org", "location" => "Here"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 5,
        "name" => "Five"
      })

    {:ok, competition} =
      Competitions.create(%{
        "name" => "Team Dup Val #{System.unique_integer([:positive])}",
        "type" => :qualification,
        "organization_id" => organization.id,
        "for_teams" => true,
        "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
      })

    {:ok, category} = Categories.create(%{"name" => "Dup Val Cat", "camera_type" => :reflex})
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
