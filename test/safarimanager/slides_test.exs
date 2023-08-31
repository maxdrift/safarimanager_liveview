defmodule SM.SlidesTest do
  use SM.DataCase

  import SM.CompetitionsFixtures

  alias SM.Slides
  alias SM.Subjects

  describe "list_duplicate_subjects/1" do
    setup [
      :create_organization,
      :create_competition,
      :create_category,
      :register_users,
      :enroll_participants
    ]

    test "lists only submitted slides", %{participants: participants} do
      [subject | _rest] = Subjects.list()
      [participant | _rest] = participants
      competition_id = participant.competition_id

      {:ok, slide1} =
        Slides.create(%{
          user_id: participant.user_id,
          competition_id: competition_id,
          file_name: "test-image-1.JPG",
          file_size: 1000,
          subject_id: subject.id,
          status: :submitted_jury
        })

      {:ok, slide2} =
        Slides.create(%{
          user_id: participant.user_id,
          competition_id: competition_id,
          file_name: "test-image-2.JPG",
          file_size: 1000,
          subject_id: subject.id,
          status: :submitted_fixed
        })

      {:ok, _slide} =
        Slides.create(%{
          user_id: participant.user_id,
          competition_id: competition_id,
          file_name: "test-image-3.JPG",
          file_size: 1000,
          subject_id: subject.id,
          status: :discarded
        })

      slide_ids = Enum.sort([slide1.id, slide2.id])

      assert [{_p1, dup1}, {_p2, dup2}] = Slides.list_duplicate_subjects(competition_id)

      dup_ids = Enum.sort([dup1.id, dup2.id])

      assert dup_ids == slide_ids
    end
  end
end
