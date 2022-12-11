defmodule SM.FileBrowser do
  @moduledoc """
  Utility module to browse the filesystem up and down the tree
  """

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

    cwd
    |> File.ls!()
    |> Enum.flat_map(fn item ->
      full_path = Path.join([cwd, item])
      extension = full_path |> Path.extname() |> String.downcase()

      cond do
        not all? and String.starts_with?(item, ".") ->
          []

        File.dir?(full_path) ->
          [%{type: :dir, name: item}]

        extension in ~w(.jpg .jpeg) ->
          [%{type: :jpg, name: item}]

        true ->
          []
      end
    end)
    |> Enum.sort(&(&1.name <= &2.name))
  end
end
