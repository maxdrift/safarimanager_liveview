NimbleCSV.define(SM.CSV, separator: ";")

defmodule SM.Seeds do
  alias SM.CSV, as: CSV
  alias SM.Evaluations
  alias SM.Subjects

  @spec run :: :ok
  def run do
    insert_subjects()
    insert_evaluations()
  end

  # Internal

  defp insert_subjects do
    priv_dir = :code.priv_dir(:safarimanager)

    [priv_dir, "/repo/elenco_pesci_2019.csv"]
    |> Path.join()
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: false)
    |> Stream.map(fn [numeric_id, name, scientific_name, coefficient] ->
      {:ok, _result} =
        Subjects.create(%{
          name: String.downcase(name),
          coefficient: String.to_integer(coefficient),
          numeric_id: String.to_integer(numeric_id),
          scientific_name: String.downcase(scientific_name),
          type: :fish
        })
    end)
    |> Stream.run()
  end

  defp insert_evaluations do
    0..10
    |> Stream.map(fn e ->
      {:ok, _result} =
        Evaluations.create(%{
          value: Decimal.new(e),
          type: "numeric"
        })
    end)
    |> Stream.run()
  end
end
