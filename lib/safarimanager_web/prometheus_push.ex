defmodule SMWeb.PrometheusPush do
  @moduledoc """
  Prometheus.io Pushgateway client.
  """

  require Logger

  @content_type "text/plain; version=0.0.4"

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

    path = build_url(job, grouping_key)

    {:ok, body} =
      case method do
        :delete ->
          {:ok, nil}

        _method ->
          get_txt_metrics(SM.PromEx)
      end

    req_opts = maybe_put_body([method: method, url: path, headers: [{"content-type", @content_type}]], body)

    case Req.request(req_client(), req_opts) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: 401}} -> {:error, :unauthorized}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, {:unexpected, reason}}
    end
  rescue
    e in RuntimeError ->
      e.message

    e in ArgumentError ->
      e.message
  end

  defp maybe_put_body(opts, nil), do: opts
  defp maybe_put_body(opts, body), do: Keyword.put(opts, :body, body)

  defp req_client do
    auth = get_config(:basic_auth)
    username = Keyword.fetch!(auth, :username)
    password = Keyword.fetch!(auth, :password)

    [
      base_url: get_config(:url),
      auth: {:basic, "#{username}:#{password}"},
      finch: SMFinch
    ]
    |> Req.new()
    |> SM.Utils.req_attach_defaults()
  end

  defp prepare_request_params(config) do
    job = Map.get(config, :job)

    grouping_key = Map.get(config, :grouping_key, %{})

    {job, grouping_key}
  end

  defp encode_grouping_key(grouping_key) when is_map(grouping_key) do
    Enum.map(grouping_key, fn {key, value} ->
      encode_grouping_key_pair(key, value)
    end)
  end

  defp encode_grouping_key(grouping_key) when is_list(grouping_key) do
    Enum.map(grouping_key, fn {key, value} ->
      encode_grouping_key_pair(key, value)
    end)
  end

  defp encode_grouping_key_pair(key, value) do
    "/#{URI.encode(to_str(key))}/#{URI.encode(to_str(value))}"
  end

  defp to_str(value) when is_atom(value) do
    Atom.to_string(value)
  end

  defp to_str(value) when is_number(value) do
    "#{inspect(value)}"
  end

  defp to_str(value) do
    IO.iodata_to_binary(value)
  end

  defp build_url(job, grouping_key) do
    grouping_key = encode_grouping_key(grouping_key)
    job = URI.encode(to_str(job))
    IO.iodata_to_binary(["/metrics/job/", job, grouping_key])
  end

  defp get_config(key) do
    :safarimanager
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end

  defp get_txt_metrics(prom_ex_module) do
    case PromEx.get_metrics(prom_ex_module) do
      :prom_ex_down ->
        Logger.warning("Attempted to fetch metrics from #{prom_ex_module}, but the module has not been initialized")

        {:error, :prom_ex_down}

      metrics ->
        PromEx.ETSCronFlusher.defer_ets_flush(prom_ex_module.__ets_cron_flusher_name__())

        {:ok, metrics}
    end
  end
end
