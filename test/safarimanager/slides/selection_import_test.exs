defmodule SM.Slides.SelectionImportTest do
  use ExUnit.Case, async: true

  alias SM.Slides.SelectionImport

  describe "parse/1" do
    test "parses supported columns and ignores extra trailing columns" do
      filename = "selection-import-#{System.unique_integer([:positive])}.csv"
      path = Path.join(System.tmp_dir!(), filename)

      csv_content = """
      IMG_001.jpg;X;12;Manta Ray;2;ignored;ignored-too
      IMG_002.jpg;;8;Turtle;1;anything
      """

      File.write!(path, csv_content)
      on_exit(fn -> File.rm(path) end)

      assert [
               %{
                 file_name: "IMG_001.jpg",
                 jury?: true,
                 subject_num: "12",
                 subject_name: "Manta Ray",
                 coefficient: "2"
               },
               %{
                 file_name: "IMG_002.jpg",
                 jury?: false,
                 subject_num: "8",
                 subject_name: "Turtle",
                 coefficient: "1"
               }
             ] = path |> SelectionImport.parse() |> Enum.to_list()
    end
  end
end
