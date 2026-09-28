defmodule SM.CompetitionDirectories.Manifest do
  @moduledoc """
  Reads and writes competition directory marker files on disk.

  On-disk contract: `docs/IMAGE_STORAGE.md`.
  """

  @root_filename ".safarimanager.json"
  @participant_filename ".safarimanager-participant.json"
  @version 1
  @max_bytes 256 * 1024

  @type root_t :: %{
          version: pos_integer(),
          library_id: String.t(),
          competitions: [
            %{
              id: String.t(),
              name: String.t(),
              linked_at: String.t()
            }
          ]
        }

  @type participant_t :: %{
          version: pos_integer(),
          library_id: String.t(),
          links: [
            %{
              competition_id: String.t(),
              user_id: String.t(),
              number: integer(),
              name: String.t()
            }
          ]
        }

  @spec root_path(String.t()) :: String.t()
  def root_path(root), do: Path.join(root, @root_filename)

  @spec participant_path(String.t()) :: String.t()
  def participant_path(folder), do: Path.join(folder, @participant_filename)

  @spec read_root(String.t()) :: {:ok, root_t()} | {:error, :missing | :invalid}
  def read_root(root) do
    root
    |> root_path()
    |> read_json()
    |> decode_root()
  end

  @spec write_root(String.t(), root_t()) :: :ok | {:error, term()}
  def write_root(root, data) do
    root |> root_path() |> write_json(data)
  end

  @spec read_participant(String.t()) :: {:ok, participant_t()} | {:error, :missing | :invalid}
  def read_participant(folder) do
    folder
    |> participant_path()
    |> read_json()
    |> decode_participant()
  end

  @spec write_participant(String.t(), participant_t()) :: :ok | {:error, term()}
  def write_participant(folder, data) do
    folder |> participant_path() |> write_json(data)
  end

  @spec new_root(String.t(), String.t(), String.t()) :: root_t()
  def new_root(library_id, competition_id, competition_name) do
    %{
      version: @version,
      library_id: library_id,
      competitions: [
        %{
          id: competition_id,
          name: competition_name,
          linked_at: DateTime.to_iso8601(DateTime.utc_now())
        }
      ]
    }
  end

  @spec add_competition_to_root(root_t(), String.t(), String.t()) :: root_t()
  def add_competition_to_root(root, competition_id, competition_name) do
    competitions = root.competitions || []

    if Enum.any?(competitions, &(&1.id == competition_id)) do
      root
    else
      entry = %{
        id: competition_id,
        name: competition_name,
        linked_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      Map.put(root, :competitions, competitions ++ [entry])
    end
  end

  @spec remove_competition_from_root(root_t(), String.t()) :: root_t()
  def remove_competition_from_root(root, competition_id) do
    competitions = Enum.reject(root.competitions || [], &(&1.id == competition_id))

    Map.put(root, :competitions, competitions)
  end

  @spec upsert_participant_link(participant_t(), map()) :: participant_t()
  def upsert_participant_link(marker, link) do
    links = marker.links || []
    key = {link.competition_id, link.user_id}

    links =
      links
      |> Enum.reject(fn entry -> {entry.competition_id, entry.user_id} == key end)
      |> Kernel.++([link])

    marker
    |> Map.put(:version, @version)
    |> Map.put(:links, links)
  end

  @spec remove_participant_link(participant_t(), String.t(), String.t()) :: participant_t()
  def remove_participant_link(marker, competition_id, user_id) do
    links =
      Enum.reject(marker.links || [], fn entry ->
        entry.competition_id == competition_id and entry.user_id == user_id
      end)

    Map.put(marker, :links, links)
  end

  @spec find_roots_with_library_id(String.t(), [String.t()]) :: [String.t()]
  def find_roots_with_library_id(library_id, search_roots) do
    search_roots
    |> Enum.flat_map(&immediate_subdirs/1)
    |> Enum.concat(search_roots)
    |> Enum.uniq()
    |> Enum.filter(&File.dir?/1)
    |> Enum.reduce([], fn dir, acc ->
      case read_root(dir) do
        {:ok, %{library_id: ^library_id}} -> [dir | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
  end

  @spec scan_participant_folders(String.t(), String.t(), String.t()) :: {:ok, String.t()} | :not_found
  def scan_participant_folders(root_path, competition_id, user_id) do
    root_path
    |> immediate_subdirs()
    |> Enum.find_value(:not_found, fn subdir ->
      if participant_linked?(subdir, competition_id, user_id), do: {:ok, Path.relative_to(subdir, root_path)}
    end)
  end

  defp participant_linked?(folder, competition_id, user_id) do
    case read_participant(folder) do
      {:ok, %{links: links}} -> Enum.any?(links, &(&1.competition_id == competition_id and &1.user_id == user_id))
      _ -> false
    end
  end

  # Internal

  defp immediate_subdirs(path) when is_binary(path) do
    case File.ls(path) do
      {:ok, names} ->
        names
        |> Enum.map(&Path.join(path, &1))
        |> Enum.filter(&File.dir?/1)

      {:error, _} ->
        []
    end
  end

  defp read_json(path) do
    with {:ok, %File.Stat{size: size}} when size <= @max_bytes <- File.stat(path),
         {:ok, content} <- File.read(path) do
      {:ok, content}
    else
      {:ok, %File.Stat{}} -> {:error, :too_large}
      {:error, :enoent} -> {:error, :missing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_json(path, data) do
    tmp = "#{path}.tmp.#{System.unique_integer([:positive])}"

    with {:ok, encoded} <- Jason.encode(data),
         :ok <- File.write(tmp, encoded),
         :ok <- File.rename(tmp, path) do
      :ok
    else
      {:error, reason} ->
        File.rm(tmp)
        {:error, reason}
    end
  end

  # Marker files live on removable media, so decode with string keys and drop malformed entries.
  defp decode_root({:ok, content}) do
    case Jason.decode(content) do
      {:ok, %{"version" => v, "library_id" => library_id, "competitions" => competitions}}
      when is_integer(v) and is_binary(library_id) and is_list(competitions) ->
        {:ok,
         %{
           version: v,
           library_id: library_id,
           competitions: Enum.flat_map(competitions, &decode_competition/1)
         }}

      _ ->
        {:error, :invalid}
    end
  end

  defp decode_root({:error, :missing}), do: {:error, :missing}
  defp decode_root({:error, _}), do: {:error, :invalid}

  defp decode_participant({:ok, content}) do
    case Jason.decode(content) do
      {:ok, %{"version" => v, "library_id" => library_id, "links" => links}}
      when is_integer(v) and is_binary(library_id) and is_list(links) ->
        {:ok, %{version: v, library_id: library_id, links: Enum.flat_map(links, &decode_link/1)}}

      _ ->
        {:error, :invalid}
    end
  end

  defp decode_participant({:error, :missing}), do: {:error, :missing}
  defp decode_participant({:error, _}), do: {:error, :invalid}

  defp decode_competition(%{"id" => id, "name" => name, "linked_at" => linked_at})
       when is_binary(id) and is_binary(name) and is_binary(linked_at) do
    [%{id: id, name: name, linked_at: linked_at}]
  end

  defp decode_competition(_), do: []

  defp decode_link(%{"competition_id" => competition_id, "user_id" => user_id} = entry)
       when is_binary(competition_id) and is_binary(user_id) do
    [
      %{
        competition_id: competition_id,
        user_id: user_id,
        number: if(is_integer(entry["number"]), do: entry["number"]),
        name: if(is_binary(entry["name"]), do: entry["name"], else: "")
      }
    ]
  end

  defp decode_link(_), do: []
end
