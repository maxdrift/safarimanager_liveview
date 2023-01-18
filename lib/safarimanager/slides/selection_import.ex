NimbleCSV.define(SM.SelectionCSV, separator: ";", escape: "\"")

defmodule SM.Slides.SelectionImport do
  @moduledoc """
  Import participants' Slides selection from CSVs
  """

  alias SM.SelectionCSV
  alias SM.Utils.CSVHelper

  @spec parse(String.t()) :: Enumerable.t()
  def parse(path) do
    SelectionCSV
    |> CSVHelper.csv_to_stream(path, skip_headers: false)
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
