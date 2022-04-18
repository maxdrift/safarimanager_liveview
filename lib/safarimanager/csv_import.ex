NimbleCSV.define(CSV, separator: ";", escape: "\"")

defmodule SM.CSVImport do
  @moduledoc """
  Import to parse participants CSVs with Slides selections
  """

  # alias NimbleCSV.RFC4180, as: CSV

  @spec parse(String.t()) :: Enumerable.t()
  def parse(path) do
    path
    |> File.stream!(read_ahead: 100_000)
    |> CSV.parse_stream(skip_headers: false)
    |> Stream.reject(fn
      [""] -> true
      _any -> false
    end)
    |> Stream.map(fn
      [file_name, jury?, subject_num, subject_name, coefficient | _] ->
        %{
          file_name: file_name,
          jury?: String.downcase(jury?) == "x",
          subject_num: subject_num,
          subject_name: subject_name,
          coefficient: coefficient
        }
    end)
  end
end
