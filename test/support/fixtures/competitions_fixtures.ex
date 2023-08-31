defmodule SM.CompetitionsFixtures do
  alias SM.AccountsFixtures
  alias SM.Categories
  alias SM.Competitions
  alias SM.Jurors
  alias SM.Organizations
  alias SM.Participants
  alias SM.Slides
  alias SM.Subjects

  def create_organization(_context) do
    {:ok, organization} =
      Organizations.create(%{"name" => "G.R.O. Sub Catania", "location" => "Catania"})

    %{organization: organization}
  end

  def create_competition(%{organization: organization}) do
    {:ok, competition} =
      Competitions.create(%{
        "name" => "Test Competition",
        "type" => :qualification,
        "organization_id" => organization.id
      })

    %{competition: competition}
  end

  def create_category(_context) do
    {:ok, category} =
      Categories.create(%{"name" => "Apnea Master", "camera_type" => :reflex})

    %{category: category}
  end

  def register_users(%{category: category, organization: organization}) do
    users =
      for _ <- 1..10 do
        AccountsFixtures.competition_user_fixture(%{
          organization_id: organization.id,
          category_id: category.id
        })
      end

    %{users: users}
  end

  def enroll_participants(%{competition: competition, users: users}) do
    participants =
      users
      |> Enum.take(9)
      |> Enum.map(fn user ->
        number = Participants.get_next_participant_number(competition.id)

        {:ok, participant} =
          Participants.create(%{
            user_id: user.id,
            competition_id: competition.id,
            category_id: user.category_id,
            number: number
          })

        participant
      end)

    %{participants: participants}
  end

  def enroll_jurors(%{competition: competition, users: users}) do
    jurors =
      users
      |> Enum.take(-1)
      |> Enum.map(fn user ->
        {:ok, juror} = Jurors.create(%{user_id: user.id, competition_id: competition.id})

        juror
      end)

    %{jurors: jurors}
  end

  def create_slides(%{participants: participants}) do
    slides =
      Enum.map(participants, fn participant ->
        slides =
          for index <- 1..10 do
            {:ok, slide} =
              Slides.create(%{
                user_id: participant.user_id,
                competition_id: participant.competition_id,
                file_name: "test-image-#{index}.JPG",
                file_size: 1000
              })

            slide
          end

        {participant.user_id, slides}
      end)
      |> Enum.into(%{})

    %{slides: slides}
  end

  def select_slides(%{slides: slides}) do
    slides =
      Enum.map(slides, fn {user_id, slides} ->
        all_subjects = Subjects.list()

        {jury_subjects, fixed_subjects} =
          all_subjects
          |> Enum.shuffle()
          |> Enum.take(8)
          |> Enum.split(5)

        {submitted_slides, discarded_slides} = Enum.split(slides, 8)
        {jury_slides, fixed_slides} = Enum.split(submitted_slides, 5)

        jury_slides =
          jury_slides
          |> Enum.zip(jury_subjects)
          |> Enum.map(fn {slide, subject} ->
            {:ok, slide} =
              Slides.update(slide, %{
                subject_id: subject.id,
                status: :submitted_jury
              })

            slide
          end)

        fixed_slides =
          fixed_slides
          |> Enum.zip(fixed_subjects)
          |> Enum.map(fn {slide, subject} ->
            {:ok, slide} =
              Slides.update(slide, %{
                subject_id: subject.id,
                status: :submitted_fixed
              })

            slide
          end)

        {user_id, jury_slides ++ fixed_slides ++ discarded_slides}
      end)
      |> Enum.into(%{})

    %{slides: slides}
  end

  def add_slide_flags(%{slides: slides}) do
    [first_user | _rest] = Map.to_list(slides)
    {_user_id, user_slides} = first_user
    [first, second, third | _rest] = user_slides

    {:ok, flag1} =
      Slides.add_slide_flag(%{
        slide_id: first.id,
        type: :wrong_subject,
        context: %{
          "from" => first.subject_id,
          "to" => second.subject_id
        }
      })

    {:ok, flag2} =
      Slides.add_slide_flag(%{
        slide_id: second.id,
        type: :unrecognizable
      })

    {:ok, flag3} =
      Slides.add_slide_flag(%{
        slide_id: third.id,
        type: :distinction
      })

    {:ok, flag4} =
      Slides.add_slide_flag(%{
        slide_id: third.id,
        type: :note,
        context: %{
          "message" => "really cool photo!"
        }
      })

    %{slide_flags: [flag1, flag2, flag3, flag4]}
  end
end
