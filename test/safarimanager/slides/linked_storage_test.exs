defmodule SM.Slides.LinkedStorageTest do
  use SM.DataCase, async: true

  import SM.CompetitionsFixtures

  alias SM.CompetitionDirectories
  alias SM.CompetitionDirectories.Manifest
  alias SM.Competitions
  alias SM.Participants
  alias SM.Participants.Participant
  alias SM.Repo
  alias SM.Slides
  alias SM.Slides.Importer
  alias SM.Slides.Slide
  alias SM.Slides.Storage

  setup [
    :create_organization,
    :create_evaluation,
    :create_competition,
    :create_category,
    :register_users,
    :enroll_participants,
    :linked_directory
  ]

  defp linked_directory(context) do
    competition = context.competition
    user = hd(context.users)

    root = Path.join(System.tmp_dir!(), "sm_linked_#{System.unique_integer([:positive])}")
    participant_dir = Path.join(root, "participant-1")
    File.mkdir_p!(participant_dir)

    source = Path.join(participant_dir, "fish.jpg")
    File.cp!(Path.expand("../../fixtures/exif_sample.jpg", __DIR__), source)

    assert {:ok, _} = CompetitionDirectories.link_root(competition.id, root)

    assert {:ok, _} =
             CompetitionDirectories.assign_participant_folder(competition.id, user.id, participant_dir)

    on_exit(fn -> File.rm_rf(root) end)

    Map.merge(context, %{user: user, source: source, participant_dir: participant_dir, root: root})
  end

  test "linked import does not copy original into uploads", %{competition: competition, user: user, source: source} do
    assert {:ok, 1} = Importer.import_paths(competition.id, user.id, [source])

    {:ok, slide} = Slides.get(competition.id, user.id, "fish.jpg")
    assert slide.storage == :linked
    refute File.exists?(Storage.internal_original_path(slide))
    assert Storage.original_reachable?(slide)
    assert File.exists?(Storage.thumbnail_path(slide, :small))
  end

  test "prepare_participant_folder then import links without a prior assignment", %{
    competition: competition,
    user: user,
    source: source,
    participant_dir: participant_dir
  } do
    {:ok, participant} = Participants.get(user.id, competition.id)
    assert {:ok, _} = participant |> Participant.folder_changeset(nil) |> Repo.update()

    assert :ok = Importer.prepare_participant_folder(competition.id, user.id, participant_dir)
    assert {:ok, %{originals_folder: "participant-1"}} = Participants.get(user.id, competition.id)

    assert {:ok, 1} = Importer.import_paths(competition.id, user.id, [source])
    {:ok, slide} = Slides.get(competition.id, user.id, "fish.jpg")
    assert slide.storage == :linked
    refute File.exists?(Storage.internal_original_path(slide))
  end

  test "import from outside the assigned folder copies internally", %{
    competition: competition,
    user: user,
    root: root
  } do
    other = Path.join(root, "other")
    File.mkdir_p!(other)
    source = Path.join(other, "outside.jpg")
    File.cp!(Path.expand("../../fixtures/exif_sample.jpg", __DIR__), source)

    assert {:ok, 1} = Importer.import_paths(competition.id, user.id, [source])
    {:ok, slide} = Slides.get(competition.id, user.id, "outside.jpg")
    assert slide.storage == :internal
    assert File.exists?(Storage.internal_original_path(slide))
  end

  test "failed files still advance progress", %{competition: competition, user: user, source: source} do
    test_pid = self()
    missing = Path.join(Path.dirname(source), "missing.jpg")

    assert {:ok, 1} =
             Importer.import_paths(competition.id, user.id, [source, missing],
               on_progress: fn processed, total -> send(test_pid, {:progress, processed, total}) end
             )

    assert_received {:progress, 2, 2}
  end

  test "deleting linked slide leaves external original", %{competition: competition, user: user, source: source} do
    {:ok, _} = Importer.import_paths(competition.id, user.id, [source])
    {:ok, slide} = Slides.get(competition.id, user.id, "fish.jpg")

    assert {:ok, _} = Slides.delete(slide)
    assert File.exists?(source)
  end

  test "deleting the competition cleans markers and keeps originals", %{
    competition: competition,
    user: user,
    source: source,
    root: root,
    participant_dir: participant_dir
  } do
    {:ok, _} = Importer.import_paths(competition.id, user.id, [source])

    assert {:ok, _} = Competitions.delete(competition)

    assert File.exists?(source)
    assert {:ok, %{competitions: []}} = Manifest.read_root(root)
    assert {:ok, %{links: []}} = Manifest.read_participant(participant_dir)
  end

  test "unlink is blocked while linked slides exist", %{competition: competition, user: user, source: source} do
    {:ok, _} = Importer.import_paths(competition.id, user.id, [source])

    assert {:error, :linked_slides_remain} = CompetitionDirectories.unlink_root(competition.id)
    assert {:ok, _} = CompetitionDirectories.get(competition.id)
  end

  test "importing from another root subfolder does not re-point linked slides", %{
    competition: competition,
    user: user,
    source: source,
    root: root
  } do
    {:ok, _} = Importer.import_paths(competition.id, user.id, [source])
    other = Path.join(root, "other")
    File.mkdir_p!(other)

    assert :ok = Importer.prepare_participant_folder(competition.id, user.id, other)
    assert {:ok, %{originals_folder: "participant-1"}} = Participants.get(user.id, competition.id)
  end

  test "assigning a folder outside the root is rejected", %{competition: competition, user: user} do
    assert {:error, :escapes_root} =
             CompetitionDirectories.assign_participant_folder(competition.id, user.id, System.tmp_dir!())
  end

  test "an escaping stored folder never resolves to a path", %{competition: competition, user: user, source: source} do
    {:ok, _} = Importer.import_paths(competition.id, user.id, [source])
    {:ok, slide} = Slides.get(competition.id, user.id, "fish.jpg")
    {:ok, participant} = Participants.get(user.id, competition.id)
    {:ok, _} = participant |> Participant.folder_changeset("../../..") |> Repo.update()

    assert Storage.original_path(slide) == nil
  end

  test "slide changesets reject path-like file names" do
    changeset = Slide.changeset(%Slide{}, %{file_name: "../../etc/passwd"})
    assert %{file_name: [_]} = errors_on(changeset)
  end

  test "participant import accepts a missing originals folder and rejects escaping ones", %{
    competition: competition,
    user: user
  } do
    {:ok, participant} = Participants.get(user.id, competition.id)

    attrs =
      participant
      |> Map.from_struct()
      |> Map.take(Participant.__schema__(:fields))
      |> Map.put(:originals_folder, nil)

    assert Participant.import_changeset(%Participant{}, attrs).valid?

    refute Participant.import_changeset(%Participant{}, %{attrs | originals_folder: "../x"}).valid?
  end
end
