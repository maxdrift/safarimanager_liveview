defmodule SM.PromEx.Plugins.TablesSize do
  @moduledoc false
  use PromEx.Plugin

  import Ecto.Query

  alias SM.Repo

  require Logger

  @event_prefix [:prom_ex, :plugin, :table, :size]

  @impl PromEx.Plugin
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 60_000)

    table_names = get_table_names()
    table_size_metrics(table_names, poll_rate)
  end

  defp table_size_metrics(table_names, poll_rate) do
    Polling.build(
      :table_size_polling_events,
      poll_rate,
      {__MODULE__, :execute_table_size, [table_names]},
      [
        # Capture the total number of rows in a DB table
        last_value(
          [:safarimanager, :prom_ex, :db, :table, :size],
          event_name: @event_prefix,
          description: "The number of rows in a table.",
          tags: [:table_name],
          tag_values: &tag_values/1,
          measurement: :size
        )
      ]
    )
  end

  @spec execute_table_size(any) :: :ok
  @doc false
  def execute_table_size(table_names) do
    _result =
      Enum.map(table_names, fn table_name ->
        :telemetry.execute(@event_prefix, %{size: get_table_size(table_name)}, %{
          table_name: table_name
        })
      end)

    :ok
  rescue
    _e in RuntimeError ->
      Logger.warning("Repo not yet active: skipping one polling cycle")
      :ok

    _e in ArgumentError ->
      :ok
  end

  defp get_table_names do
    {:ok, modules} = :application.get_key(:safarimanager, :modules)

    modules
    |> Enum.filter(fn module ->
      {:__schema__, 1} in module.__info__(:functions) and
        String.starts_with?(Atom.to_string(module), "Elixir.SM.") and
        not is_nil(module.__schema__(:source))
    end)
    |> Enum.map(& &1.__schema__(:source))
  end

  defp get_table_size(table_module) do
    Repo.one(from(table_module, select: count()))
  end

  defp tag_values(metadata) do
    %{table_name: metadata.table_name}
  end
end
