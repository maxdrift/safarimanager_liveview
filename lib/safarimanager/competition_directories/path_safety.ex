defmodule SM.CompetitionDirectories.PathSafety do
  @moduledoc false

  @spec expand_root(String.t()) :: {:ok, String.t()} | {:error, :invalid}
  def expand_root(path) when is_binary(path) do
    expanded = Path.expand(path)

    if expanded != "/" and File.dir?(expanded) do
      {:ok, expanded}
    else
      {:error, :invalid}
    end
  end

  @spec relative_folder(String.t(), String.t()) :: {:ok, String.t()} | {:error, :escapes_root}
  def relative_folder(root_path, folder_path) do
    root = Path.expand(root_path)
    folder = Path.expand(folder_path)

    cond do
      folder == root -> {:ok, "."}
      String.starts_with?(folder, root <> "/") -> {:ok, normalize_relative(Path.relative_to(folder, root))}
      true -> {:error, :escapes_root}
    end
  end

  @spec inside_root?(String.t(), String.t()) :: boolean()
  def inside_root?(root_path, path) do
    match?({:ok, _}, relative_folder(root_path, path))
  end

  @doc """
  True when both paths resolve to the same folder under `root_path`.
  """
  @spec same_folder?(String.t(), String.t(), String.t()) :: boolean()
  def same_folder?(root_path, path_a, path_b) do
    with {:ok, rel_a} <- relative_folder(root_path, path_a),
         {:ok, rel_b} <- relative_folder(root_path, path_b) do
      rel_a == rel_b
    else
      _ -> false
    end
  end

  @doc """
  Joins a stored relative folder onto the root, refusing results outside the root.
  """
  @spec participant_folder_path(String.t(), String.t()) :: {:ok, String.t()} | {:error, :escapes_root}
  def participant_folder_path(root_path, relative_folder) do
    relative = normalize_relative(relative_folder)
    path = root_path |> Path.join(relative) |> Path.expand()

    if inside_root?(root_path, path), do: {:ok, path}, else: {:error, :escapes_root}
  end

  @doc """
  Normalizes a stored relative folder (`"./a/b"`, `"a//b"`) to a stable form (`"a/b"` or `"."`).
  """
  @spec normalize_relative(String.t()) :: String.t()
  def normalize_relative(relative) when is_binary(relative) do
    parts =
      relative
      |> Path.split()
      |> Enum.reject(&(&1 in ["", "."]))

    case parts do
      [] -> "."
      _ -> Path.join(parts)
    end
  end

  @spec safe_file_name?(term()) :: boolean()
  def safe_file_name?(name) when is_binary(name) do
    name not in ["", ".", ".."] and Path.basename(name) == name and
      not String.contains?(name, ["/", "\\", <<0>>])
  end

  def safe_file_name?(_), do: false
end
