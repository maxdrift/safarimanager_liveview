defmodule Sleipnir.Client.Tesla do
  @moduledoc """
  Tesla client for Sleipnir.
  """

  @type base_url :: String.t()
  @type opts :: Keyword.t()

  @doc """
  Returns a Tesla client set up to send logs to Loki.

  ## Options

  - `:org_id` - Must be specified when using Loki in multi-tenancy mode (i.e. auth_enabled is `true`). Sets the X-Scope_orgID header accordingly Sets the X-Scope-OrgID header accordingly
  """
  @spec new(base_url, opts) :: Tesla.Client.t()
  def new(base_url, opts \\ []) do
    middleware = [
      {Tesla.Middleware.Headers, headers(opts)},
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Telemetry, []},
      {Tesla.Middleware.Retry,
       [
         delay: 200,
         max_retries: 5,
         max_delay: 5_000,
         jitter_factor: 0.2,
         should_retry: fn
           {:ok, _} -> false
           {:error, _} -> true
         end
       ]}
    ]

    Tesla.client(middleware, Tesla.Adapter.Hackney)
  end

  defp headers(opts) do
    [{"Content-Type", "application/json"}]
    |> Enum.concat(maybe_add_org_id(opts))
  end

  defp maybe_add_org_id(opts) do
    case Keyword.get(opts, :org_id) do
      nil -> []
      org_id -> [{"X-Scope-OrgID", org_id}]
    end
  end
end

defimpl Sleipnir.Client, for: Tesla.Client do
  alias Logproto.EntryAdapter
  alias Logproto.PushRequest
  alias Logproto.StreamAdapter

  alias Sleipnir.Paths

  @type opts :: Keyword.t()
  @type client :: Tesla.Client.t()

  @spec push(client, PushRequest.t(), opts) :: Sleipnir.Client.response()
  def push(client, %PushRequest{} = request, opts \\ []) do
    payload = JSON.encode_to_iodata!(%{streams: Enum.map(request.streams, &encode_stream/1)})
    path = Keyword.get(opts, :path, Paths.push())

    client
    |> Tesla.post(path, payload)
    |> case do
      {:ok, response} -> {:ok, parse(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp encode_stream(%StreamAdapter{labels: labels, entries: entries}) do
    %{
      stream: decode_labels(labels),
      values: Enum.map(entries, &encode_entry/1)
    }
  end

  # `Sleipnir.stream/2` stores labels as a JSON-encoded map for transport.
  defp decode_labels(labels) when is_binary(labels), do: JSON.decode!(labels)

  defp encode_entry(%EntryAdapter{line: line, timestamp: timestamp}) do
    [to_string(nanoseconds(timestamp)), to_string(line)]
  end

  defp nanoseconds(%Google.Protobuf.Timestamp{seconds: seconds, nanos: nanos}) do
    seconds * 1_000_000_000 + nanos
  end

  defp parse(response) do
    Map.take(response, [:headers, :status])
  end
end
