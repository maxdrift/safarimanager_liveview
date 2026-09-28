defmodule SM.CompetitionDirectories.Volumes do
  @moduledoc false

  @spec list_mount_points() :: [String.t()]
  def list_mount_points do
    "mount"
    |> System.cmd([])
    |> elem(0)
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Regex.named_captures(~r{^(?<device>.+) on (?<mountpoint>.+) \((?<mode>.+)\)$}, line) do
        %{"mountpoint" => mountpoint} -> [mountpoint]
        nil -> []
      end
    end)
    |> Enum.sort()
  rescue
    ErlangError -> []
  end

  @spec search_roots_for_relocate(String.t()) :: [String.t()]
  def search_roots_for_relocate(old_root_path) do
    old_root_path = Path.expand(old_root_path)
    parent = Path.dirname(old_root_path)

    Enum.uniq([old_root_path, parent | list_mount_points()])
  end
end
