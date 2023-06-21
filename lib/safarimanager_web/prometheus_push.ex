defmodule SMWeb.PrometheusPush do
  @moduledoc """
  Prometheus.io Pushgateway client.
  """

  use Tesla

  require Logger

  @content_type "text/plain; version=0.0.4"

  adapter Tesla.Adapter.Finch, name: SMFinch

  plug Tesla.Middleware.BaseUrl, get_config(:url)
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.BasicAuth, get_config(:basic_auth)
  plug Tesla.Middleware.Logger, debug: false, log_level: &log_level/1
  plug Tesla.Middleware.Headers, [{"content-type", @content_type}]
  plug Tesla.Middleware.PathParams
  plug Tesla.Middleware.Telemetry

  def push do
    do_request(:put, %{})
  end

  def push(options) when is_map(options) do
    do_request(:put, options)
  end

  def push(job) do
    do_request(:put, %{job: job})
  end

  def add do
    do_request(:post, %{})
  end

  def add(options) when is_map(options) do
    do_request(:post, options)
  end

  def add(job) do
    do_request(:post, %{job: job})
  end

  def remove do
    do_request(:delete, %{})
  end

  def remove(options) when is_map(options) do
    do_request(:delete, options)
  end

  def remove(job) do
    do_request(:delete, %{job: job})
  end

  def hostname_grouping_key do
    {:ok, hostname} = :inet.gethostname()

    %{instance: hostname}
  end

  # Internal

  defp do_request(method, request) do
    {job, grouping_key} = prepare_request_params(request)

    url = build_url(job, grouping_key)

    {:ok, body} =
      case method do
        :delete ->
          {:ok, nil}

        _method ->
          get_txt_metrics(SM.PromEx)
      end

    case request(method: method, url: url, body: body) do
      {:ok, %Tesla.Env{status: status}} when status in 200..299 -> :ok
      {:ok, %Tesla.Env{status: 401}} -> {:error, :unauthorized}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, {:unexpected, reason}}
    end
  rescue
    e in RuntimeError ->
      e.message

    e in ArgumentError ->
      e.message
  end

  defp prepare_request_params(config) do
    job = Map.get(config, :job)

    grouping_key = Map.get(config, :grouping_key, %{})

    {job, grouping_key}
  end

  # encode_grouping_key(GK) when is_map(GK) ->
  #   maps:fold(fun(K, V, Acc) ->
  #                 [encode_grouping_key_pair(K, V) ++ Acc]
  #             end,
  #             [],
  #             GK);
  defp encode_grouping_key(grouping_key) when is_map(grouping_key) do
    Enum.map(grouping_key, fn {key, value} ->
      encode_grouping_key_pair(key, value)
    end)
  end

  # encode_grouping_key(GK) when is_list(GK) ->
  #   lists:foldl(fun({K, V}, Acc) ->
  #                   [encode_grouping_key_pair(K, V) ++ Acc]
  #               end,
  #               [],
  #               GK).
  defp encode_grouping_key(grouping_key) when is_list(grouping_key) do
    Enum.map(grouping_key, fn {key, value} ->
      encode_grouping_key_pair(key, value)
    end)
  end

  # encode_grouping_key_pair(K, V) ->
  #   ["/", http_uri:encode(to_string(K)),
  #   "/", http_uri:encode(to_string(V))].
  defp encode_grouping_key_pair(key, value) do
    "/#{URI.encode(to_str(key))}/#{URI.encode(to_str(value))}"
  end

  # to_string_(Val) when is_atom(Val) ->
  #   atom_to_binary(Val, utf8);
  defp to_str(value) when is_atom(value) do
    Atom.to_string(value)
  end

  # to_string_(Val) when is_number(Val) ->
  #   io_lib:format("~p", [Val]);
  defp to_str(value) when is_number(value) do
    "#{inspect(value)}"
  end

  # to_string_(Val) ->
  #   try iolist_to_binary(Val) of
  #       Str -> Str
  #   catch
  #     error:badarg ->
  #       erlang:error({to_string_failed, Val})
  #   end.
  defp to_str(value) do
    IO.iodata_to_binary(value)
  end

  defp build_url(job, grouping_key) do
    # TODO: Tidy up encoding here
    grouping_key = encode_grouping_key(grouping_key)
    job = URI.encode(to_str(job))
    IO.iodata_to_binary(["/metrics/job/", job, grouping_key])
  end

  defp get_config(key) do
    :safarimanager
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end

  defp log_level(env) do
    case env.status do
      200 -> :debug
      _ -> :default
    end
  end

  defp get_txt_metrics(prom_ex_module) do
    case PromEx.get_metrics(prom_ex_module) do
      :prom_ex_down ->
        Logger.warning(
          "Attempted to fetch metrics from #{prom_ex_module}, but the module has not been initialized"
        )

        {:error, :prom_ex_down}

      metrics ->
        PromEx.ETSCronFlusher.defer_ets_flush(prom_ex_module.__ets_cron_flusher_name__())

        {:ok, metrics}
    end
  end
end
