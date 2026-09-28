defmodule SM.CompetitionDirectories.ManifestTest do
  use ExUnit.Case, async: true

  alias SM.CompetitionDirectories.Manifest

  setup do
    root = Path.join(System.tmp_dir!(), "sm_manifest_#{System.unique_integer()}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)
    %{root: root}
  end

  test "root manifest round-trip and multi-competition", %{root: root} do
    library_id = Ecto.UUID.generate()
    root_data = Manifest.new_root(library_id, Ecto.UUID.generate(), "Comp A")
    assert :ok = Manifest.write_root(root, root_data)
    assert {:ok, read} = Manifest.read_root(root)
    assert read.library_id == library_id

    updated = Manifest.add_competition_to_root(read, Ecto.UUID.generate(), "Comp B")
    assert :ok = Manifest.write_root(root, updated)
    assert {:ok, read2} = Manifest.read_root(root)
    assert length(read2.competitions) == 2
  end

  test "participant marker supports multiple links", %{root: root} do
    folder = Path.join(root, "p1")
    File.mkdir_p!(folder)

    marker = %{
      version: 1,
      library_id: Ecto.UUID.generate(),
      links: [
        %{
          competition_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate(),
          number: 1,
          name: "Alice"
        }
      ]
    }

    assert :ok = Manifest.write_participant(folder, marker)
    assert {:ok, read} = Manifest.read_participant(folder)

    link2 = %{
      competition_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      number: 2,
      name: "Bob"
    }

    updated = Manifest.upsert_participant_link(read, link2)
    assert length(updated.links) == 2
  end

  test "scan finds participant folder after rename by marker content", %{root: root} do
    comp_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    folder = Path.join(root, "renamed-folder")
    File.mkdir_p!(folder)

    marker = %{
      version: 1,
      library_id: Ecto.UUID.generate(),
      links: [%{competition_id: comp_id, user_id: user_id, number: 7, name: "Test"}]
    }

    :ok = Manifest.write_participant(folder, marker)

    assert {:ok, "renamed-folder"} =
             Manifest.scan_participant_folders(root, comp_id, user_id)
  end
end
