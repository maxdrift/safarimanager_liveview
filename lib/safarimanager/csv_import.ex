NimbleCSV.define(CSV, separator: ";", escape: "\"")

defmodule SM.CSVImport do
  @moduledoc """
  Import to parse participants CSVs with Slides selections
  """

  # alias NimbleCSV.RFC4180, as: CSV

  def parse(path) do
    path
    |> File.stream!(read_ahead: 100_000)
    |> CSV.parse_stream(skip_headers: false)
    |> Stream.map(fn [file_name, jury?, subject_num, subject_name, coefficient] ->
      %{
        file_name: file_name,
        jury?: jury?,
        subject_num: subject_num,
        subject_name: subject_name,
        coefficient: coefficient
      }
    end)
    |> Enum.to_list()
  end
end
