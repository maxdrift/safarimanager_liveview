NimbleCSV.define(SM.SeedsCSV, separator: ";")

defmodule SM.Seeds do
  @moduledoc """
  Seeds helper
  """
  alias SM.Categories
  alias SM.Evaluations
  alias SM.SeedsCSV, as: SeedsCSV
  alias SM.Subjects

  @default_categories [
    "Apnea Master",
    "ARA Master",
    "Apnea Compatte",
    "ARA Compatte",
    "Esordienti"
  ]

  @spec run :: :ok
  def run do
    insert_subjects()
    insert_evaluations()
    insert_categories()
  end

  def insert_subjects do
    priv_dir = :code.priv_dir(:safarimanager)

    [priv_dir, "/repo/elenco_pesci_2019.csv"]
    |> Path.join()
    |> File.stream!()
    |> SeedsCSV.parse_stream(skip_headers: false)
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

  @spec upsert_subjects :: :ok
  def upsert_subjects do
    priv_dir = :code.priv_dir(:safarimanager)

    [priv_dir, "/repo/elenco_pesci_2019.csv"]
    |> Path.join()
    |> File.stream!()
    |> SeedsCSV.parse_stream(skip_headers: false)
    |> Stream.map(fn [numeric_id, name, scientific_name, coefficient] ->
      data = %{
        name: String.downcase(name),
        coefficient: String.to_integer(coefficient),
        numeric_id: String.to_integer(numeric_id),
        scientific_name: String.downcase(scientific_name),
        type: :fish
      }

      case Subjects.get_by_numeric_id(numeric_id) do
        {:ok, subject} ->
          {:ok, _result} = Subjects.update(subject, data)

        {:error, :not_found} ->
          {:ok, _result} = Subjects.create(data)
      end
    end)
    |> Stream.run()
  end

  def insert_evaluations do
    0..10
    |> Stream.map(fn e ->
      {:ok, _result} =
        Evaluations.create(%{
          name: to_string(e),
          value: Decimal.new(e),
          type: "numeric"
        })
    end)
    |> Stream.run()

    {:ok, _result} =
      Evaluations.create(%{
        name: "P",
        value: Decimal.new("0"),
        is_penalty: true,
        type: "boolean",
        description: "Penalty"
      })
  end

  def insert_categories do
    :ok =
      @default_categories
      |> Stream.map(fn name ->
        {:ok, _result} = Categories.create(%{name: name})
      end)
      |> Stream.run()
  end
end
