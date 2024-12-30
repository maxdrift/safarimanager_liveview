defmodule SM.Config do
  @moduledoc false

  @doc """
  Returns the longname if the distribution mode is configured to use long names.
  """
  @spec longname :: binary() | nil
  def longname do
    host = SM.Utils.node_host()

    if host =~ "." do
      host
    end
  end

  @doc """
  Returns the home path.
  """
  @spec home :: String.t()
  def home do
    Application.get_env(:safarimanager, :home) || user_home() || File.cwd!()
  end

  defp user_home, do: Path.expand(System.user_home())

  @doc """
  Returns the configured port for the Safarimanager endpoint.

  Note that the value may be `0`.
  """
  @spec port :: pos_integer() | 0
  def port do
    Application.get_env(:safarimanager, SMWeb.Endpoint)[:http][:port]
  end

  @doc """
  Returns the base url path for the Safarimanager endpoint.
  """
  @spec base_url_path :: String.t()
  def base_url_path do
    path = Application.get_env(:safarimanager, SMWeb.Endpoint)[:url][:path]
    String.trim_trailing(path, "/")
  end

  @doc """
  Shuts down the system, if possible.
  """
  def shutdown do
    case SM.Config.shutdown_callback() do
      {m, f, a} ->
        _result = Phoenix.PubSub.broadcast(SM.PubSub, "sidebar", :shutdown)
        apply(m, f, a)

      nil ->
        :ok
    end
  end

  @doc """
  Returns an mfa if there's a way to shut down the system.
  """
  @spec shutdown_callback() :: {module(), atom(), list()} | nil
  def shutdown_callback do
    Application.fetch_env!(:safarimanager, :shutdown_callback)
  end

  @doc """
  Returns the update check URL.
  """
  @spec update_instructions_url() :: String.t() | nil
  def update_instructions_url do
    Application.fetch_env!(:safarimanager, :update_instructions_url)
  end

  @doc """
  Returns the application cacertfile if any.
  """
  # TODO: Remove env var once support is added either to Erlang/OTP 28 or Elixir v1.18
  @spec cacertfile() :: String.t() | nil
  def cacertfile do
    Application.get_env(:safarimanager, :cacertfile)
  end

  @feature_flags Application.compile_env(:safarimanager, :feature_flags)

  @doc """
  Returns the feature flag list.
  """
  @spec feature_flags() :: keyword(boolean())
  def feature_flags do
    @feature_flags
  end

  @doc """
  Returns enabled feature flags.
  """
  @spec enabled_feature_flags() :: list()
  def enabled_feature_flags do
    for {flag, enabled?} <- feature_flags(), enabled?, do: flag
  end

  @doc """
  Return if the feature flag is enabled.
  """
  @spec feature_flag_enabled?(atom()) :: boolean()
  def feature_flag_enabled?(key) do
    Keyword.get(@feature_flags, key, false)
  end

  ## Parsing

  @doc """
  Parses and validates dir from env.
  """
  def writable_dir!(env) do
    if dir = System.get_env(env) do
      writable_dir!(env, dir)
    end
  end

  @doc """
  Validates `dir` within context.
  """
  def writable_dir!(context, dir) do
    if writable_dir?(dir) do
      Path.expand(dir)
    else
      abort!("expected #{context} to be a writable directory: #{dir}")
    end
  end

  defp writable_dir?(path) do
    case File.stat(path) do
      {:ok, %{type: :directory, access: access}} when access in [:read_write, :write] -> true
      _ -> false
    end
  end

  @doc """
  Parses and validates the secret from env.
  """
  def secret!(env) do
    if secret_key_base = System.get_env(env) do
      if byte_size(secret_key_base) < 64 do
        abort!(
          "cannot start Safarimanager because #{env} must be at least 64 characters. " <>
            "Invoke `openssl rand -base64 48` to generate an appropriately long secret."
        )
      end

      secret_key_base
    end
  end

  @doc """
  Parses and validates the port from env.
  """
  def port!(env) do
    if port = System.get_env(env) do
      case Integer.parse(port) do
        {port, ""} -> port
        :error -> abort!("expected #{env} to be an integer, got: #{inspect(port)}")
      end
    end
  end

  @doc """
  Parses and validates the base url path from env.
  """
  def base_url_path!(env) do
    if base_url_path = System.get_env(env) do
      String.trim_trailing(base_url_path, "/")
    end
  end

  @doc """
  Parses and validates the ip from env.
  """
  def ip!(env) do
    if ip = System.get_env(env) do
      ip!(env, ip)
    end
  end

  @doc """
  Parses and validates the ip within context.
  """
  def ip!(context, ip) do
    case ip |> String.to_charlist() |> :inet.parse_address() do
      {:ok, ip} ->
        ip

      {:error, :einval} ->
        abort!("expected #{context} to be a valid ipv4 or ipv6 address, got: #{ip}")
    end
  end

  @doc """
  Parses the cookie from env.
  """
  def cookie!(env) do
    if cookie = System.get_env(env) do
      # credo:disable-for-next-line
      String.to_atom(cookie)
    end
  end

  @doc """
  Parses node and distribution type from env.
  """
  def node!(node_env, distribution_env) do
    case {System.get_env(node_env), System.get_env(distribution_env, "sname")} do
      {nil, _} ->
        nil

      {name, "name"} ->
        # credo:disable-for-next-line
        {:longnames, String.to_atom(name)}

      {sname, "sname"} ->
        # credo:disable-for-next-line
        {:shortnames, String.to_atom(sname)}

      {_, other} ->
        abort!(~s(#{distribution_env} must be one of "name" or "sname", got "#{other}"))
    end
  end

  @doc """
  Parses and validates the password from env.
  """
  def password!(env) do
    if password = System.get_env(env) do
      if byte_size(password) < 12 do
        abort!("cannot start Safarimanager because #{env} must be at least 12 characters")
      end

      password
    end
  end

  @doc """
  Parses token auth setting from env.
  """
  def boolean!(env, default \\ false) do
    case System.get_env(env) do
      nil -> default
      var -> var in ~w(true 1)
    end
  end

  @doc """
  Parses update instructions url from env.
  """
  def update_instructions_url!(env) do
    System.get_env(env)
  end

  @doc """
  Parses and validates allowed URI schemes from env.
  """
  def allowed_uri_schemes!(env) do
    if schemes = System.get_env(env) do
      String.split(schemes, ",", trim: true)
    end
  end

  @doc """
  Returns the current version of running Safarimanager.
  """
  def app_version, do: :safarimanager |> Application.spec(:vsn) |> List.to_string()

  @doc """
  Aborts booting due to a configuration error.
  """
  @spec abort!(String.t()) :: no_return()
  def abort!(message) do
    IO.puts("\nERROR!!! [SafariManager] " <> message)
    System.halt(1)
  end

  @spec get_private_network_address :: {:error, :address_not_found} | {:ok, tuple()}
  def get_private_network_address do
    with {:ok, ifaddrs} <- :inet.getifaddrs() do
      ifaddrs
      |> Enum.flat_map(fn {_name, opts} -> Keyword.get_values(opts, :addr) end)
      |> Enum.filter(fn
        {first, _sec, _third, _fourth} when first in [10, 172, 192] -> true
        _addr -> false
      end)
      |> case do
        [first | _rest] -> {:ok, first}
        [] -> {:error, :address_not_found}
      end
    end
  end
end
