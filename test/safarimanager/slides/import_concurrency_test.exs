defmodule SM.Slides.ImportConcurrencyTest do
  use SM.DataCase, async: false

  import ExUnit.CaptureLog
  import SM.CompetitionsFixtures

  alias SM.CompetitionDirectories
  alias SM.Slides
  alias SM.Slides.Importer

  @fixture Path.expand("../../fixtures/exif_sample.jpg", __DIR__)

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

    root = Path.join(System.tmp_dir!(), "sm_import_conc_#{System.unique_integer([:positive])}")
    participant_dir = Path.join(root, "participant-1")
    File.mkdir_p!(participant_dir)

    assert {:ok, _} = CompetitionDirectories.link_root(competition.id, root)

    assert {:ok, _} =
             CompetitionDirectories.assign_participant_folder(competition.id, user.id, participant_dir)

    on_exit(fn -> File.rm_rf(root) end)

    Map.merge(context, %{user: user, participant_dir: participant_dir, root: root})
  end

  test "concurrent linked import of many distinct files succeeds", %{
    competition: competition,
    user: user,
    participant_dir: participant_dir
  } do
    count = 24

    sources =
      Enum.map(1..count, fn i ->
        dest = Path.join(participant_dir, "fish_#{i}.jpg")
        File.cp!(@fixture, dest)
        dest
      end)

    log =
      capture_log(fn ->
        assert {:ok, ^count} = Importer.import_paths(competition.id, user.id, sources)
      end)

    refute log =~ "Database busy"
    refute log =~ "Falling back to LIKE query"

    slides = Slides.list(user.id, competition.id)
    assert length(slides) == count
    assert Enum.all?(slides, &(&1.storage == :linked))
  end

  test "exact filename miss does not fall back to LIKE", %{
    competition: competition,
    user: user
  } do
    log =
      capture_log(fn ->
        assert {:error, :not_found} = Slides.get(competition.id, user.id, "missing_file.JPG")
      end)

    refute log =~ "Falling back to LIKE query"
  end

  test "extension-less lookup still uses LIKE fallback", %{
    competition: competition,
    user: user,
    participant_dir: participant_dir
  } do
    source = Path.join(participant_dir, "legacy.jpg")
    File.cp!(@fixture, source)
    assert {:ok, 1} = Importer.import_paths(competition.id, user.id, [source])

    log =
      capture_log(fn ->
        assert {:ok, slide} = Slides.get(competition.id, user.id, "legacy")
        assert slide.file_name == "legacy.jpg"
      end)

    assert log =~ "Falling back to LIKE query"
  end

  test "create_slide_from_file returns existing on duplicate without error", %{
    competition: competition,
    user: user,
    participant_dir: participant_dir
  } do
    source = Path.join(participant_dir, "dup.jpg")
    File.cp!(@fixture, source)
    size = File.stat!(source).size

    assert {:ok, first} =
             Slides.create_slide_from_file(
               competition.id,
               user.id,
               "dup.jpg",
               size,
               "image/jpeg",
               source,
               :linked
             )

    assert {:ok, second} =
             Slides.create_slide_from_file(
               competition.id,
               user.id,
               "dup.jpg",
               size,
               "image/jpeg",
               source,
               :linked
             )

    assert first.id == second.id
  end
end
