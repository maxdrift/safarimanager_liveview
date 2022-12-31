defmodule SM.FileBrowser do
  @moduledoc """
  Utility module to browse the filesystem up and down the tree
  """

  @extension_type_mapping %{
    "jpg" => :img,
    "jpeg" => :img,
    "png" => :img,
    "csv" => :txt
  }

  @type_extension_mapping %{
    jpg: ["jpg", "jpeg"],
    png: ["png"],
    csv: ["csv"]
  }

  def cd(path) do
    {:ok, Path.expand(path)}
  end

  @spec cd(String.t(), String.t() | %{:name => String.t(), :type => :dir}) :: {:ok, String.t()}
  def cd(cwd, "..") do
    {:ok, Path.dirname(cwd)}
  end

  def cd(cwd, %{name: dir_name, type: :dir}) do
    cd(cwd, dir_name)
  end

  def cd(cwd, path) do
    full_path =
      cwd
      |> Path.join(path)
      |> Path.expand()

    {:ok, full_path}
  end

  @spec ls!(String.t(), keyword()) :: list()
  def ls!(cwd, opts \\ []) do
    all? = Keyword.get(opts, :all, false)
    filter = Keyword.get(opts, :filter, [])
    ext_filter = reduce_file_filter(filter)

    cwd
    |> File.ls!()
    |> Enum.flat_map(fn item ->
      full_path = Path.join([cwd, item])

      extension =
        full_path
        |> Path.extname()
        |> String.trim_leading(".")
        |> String.downcase()

      type = Map.get(@extension_type_mapping, extension, :other)

      cond do
        not all? and String.starts_with?(item, ".") ->
          []

        File.dir?(full_path) ->
          [%{type: :dir, name: item, selectable: true}]

        ext_filter == [] or extension in ext_filter ->
          [%{type: type, name: item, selectable: true}]

        true ->
          [%{type: type, name: item, selectable: false}]
      end
    end)
    |> Enum.sort(&(&1.name <= &2.name))
  end

  def reduce_file_filter(types) do
    Enum.flat_map(types, fn type ->
      case Map.fetch(@type_extension_mapping, type) do
        {:ok, value} -> value
        :error -> [Atom.to_string(type)]
      end
    end)
  end
end
