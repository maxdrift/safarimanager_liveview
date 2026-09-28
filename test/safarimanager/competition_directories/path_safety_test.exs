defmodule SM.CompetitionDirectories.PathSafetyTest do
  use ExUnit.Case, async: true

  alias SM.CompetitionDirectories.PathSafety

  test "relative_folder accepts the root and its descendants" do
    assert {:ok, "."} = PathSafety.relative_folder("/data/root", "/data/root")
    assert {:ok, "p1"} = PathSafety.relative_folder("/data/root", "/data/root/p1")
    assert {:ok, "a/b"} = PathSafety.relative_folder("/data/root/", "/data/root/x/../a/b")
  end

  test "normalize_relative collapses dots and empty segments" do
    assert PathSafety.normalize_relative(".") == "."
    assert PathSafety.normalize_relative("./p1") == "p1"
    assert PathSafety.normalize_relative("a//b") == "a/b"
  end

  test "same_folder? compares by relative location under the root" do
    assert PathSafety.same_folder?("/data/root", "/data/root/p1", "/data/root/x/../p1")
    refute PathSafety.same_folder?("/data/root", "/data/root/p1", "/data/root/p2")
  end

  test "relative_folder rejects outside, parent and sibling-prefix paths" do
    assert {:error, :escapes_root} = PathSafety.relative_folder("/data/root", "/etc")
    assert {:error, :escapes_root} = PathSafety.relative_folder("/data/root", "/data")
    assert {:error, :escapes_root} = PathSafety.relative_folder("/data/root", "/data/root2/p1")
    assert {:error, :escapes_root} = PathSafety.relative_folder("/data/root", "/data/root/../etc")
  end

  test "participant_folder_path refuses stored folders that escape the root" do
    assert {:ok, "/data/root/p1"} = PathSafety.participant_folder_path("/data/root", "p1")
    assert {:error, :escapes_root} = PathSafety.participant_folder_path("/data/root", "../../etc")
  end

  test "safe_file_name? only accepts plain basenames" do
    assert PathSafety.safe_file_name?("fish 01.jpg")
    refute PathSafety.safe_file_name?("../../etc/passwd")
    refute PathSafety.safe_file_name?("a/b.jpg")
    refute PathSafety.safe_file_name?("..")
    refute PathSafety.safe_file_name?(nil)
  end
end
