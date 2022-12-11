defmodule SM.FileBrowser do
  @moduledoc """
  Utility module to browse the filesystem up and down the tree
  """

  @spec cd(String.t() | %{:name => String.t(), :type => :dir}) ::
          {:ok, String.t()} | {:error, atom()}
  def cd("..") do
    File.cwd!()
    |> Path.dirname()
    |> File.cd()
    |> case do
      :ok -> {:ok, File.cwd!()}
      {:error, _reason} = error -> error
    end
  end

  def cd(%{name: dir_name, type: :dir}) do
    cd(dir_name)
  end

  def cd(path) do
    path
    |> Path.expand()
    |> File.cd()
    |> case do
      :ok -> {:ok, File.cwd!()}
      {:error, _reason} = error -> error
    end
  end

  @spec ls!(keyword()) :: list()
  def ls!(opts \\ []) do
    all? = Keyword.get(opts, :all, false)
    cwd = File.cwd!()

    File.ls!()
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
