defmodule SM.Utils.CSVHelper do
  @moduledoc """
  Helper module to handle CSV import/export
  """

  alias NimbleCSV.RFC4180, as: CSV

  @doc """
  Converts a CSV file to a stream
  """
  @spec csv_to_stream(atom(), String.t(), Keyword.t()) :: Enumerable.t()
  def csv_to_stream(parser \\ CSV, filename, opts \\ []) do
    skip_headers = Keyword.get(opts, :skip_headers, true)
    read_ahead = Keyword.get(opts, :read_ahead, 100_000)

    filename
    |> File.stream!(read_ahead: read_ahead)
    |> parser.parse_stream(skip_headers: skip_headers)
  end

  @doc """
  Converts a stream of rows to a stream of CSV columns
  """
  @spec stream_to_csv(Enumerable.t(), [String.t()]) :: Enumerable.t()
  def stream_to_csv(rows, headers) do
    [headers]
    |> Stream.concat(rows)
    |> CSV.dump_to_stream()
  end

  @doc """
  Converts a stream of rows to a CSV file
  """
  @spec stream_to_csv_file(Enumerable.t(), [String.t()], String.t()) :: {:ok, String.t()}
  def stream_to_csv_file(rows, headers, filename) do
    :ok =
      rows
      |> stream_to_csv(headers)
      |> Stream.into(File.stream!(filename))
      |> Stream.run()

    {:ok, filename}
  end
end
