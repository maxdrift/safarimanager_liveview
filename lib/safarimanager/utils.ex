defmodule SM.Utils do
  @moduledoc false

  import SMWeb.Gettext

  alias SM.Slides.Slide

  require Logger

  @type id :: binary()

  @doc """
  Returns a Slide's thumbnail public resource path
  """
  @spec slide_thumbnail_path(Slide.t(), atom()) :: String.t()
  def slide_thumbnail_path(slide, size \\ :small) do
    "/uploads/#{slide.competition_id}/#{slide.user_id}/thumbnails/#{size}/#{slide.file_name}"
  end

  @doc """
  Returns a Slide's public resource path
  """
  @spec slide_path(Slide.t()) :: String.t()
  def slide_path(slide) do
    "/uploads/#{slide.competition_id}/#{slide.user_id}/#{slide.file_name}"
  end

  @spec pretty_dates(nil | DateTime.t(), any()) :: String.t()
  def pretty_dates(%DateTime{day: day, month: month, year: year} = start_time, %DateTime{
        day: day,
        month: month,
        year: year
      }) do
    Calendar.strftime(start_time, "%d %b %Y")
  end

  def pretty_dates(%DateTime{month: month, year: year} = start_time, %DateTime{month: month, year: year} = end_time) do
    Calendar.strftime(start_time, "%d → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  def pretty_dates(%DateTime{year: year} = start_time, %DateTime{year: year} = end_time) do
    Calendar.strftime(start_time, "%d %b → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  def pretty_dates(%DateTime{year: _year1} = start_time, %DateTime{year: _year2} = end_time) do
    Calendar.strftime(start_time, "%d %b %Y → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  def pretty_dates(%DateTime{} = start_time, nil) do
    Calendar.strftime(start_time, "%d %b %Y")
  end

  def pretty_dates(nil, _nil) do
    gettext("Sometime...")
  end

  @doc """
  Generates a random binary id.
  """
  @spec random_id() :: id()
  def random_id do
    20
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(case: :lower)
  end

  @doc """
  Generates a random short binary id.
  """
  @spec random_short_id() :: id()
  def random_short_id do
    5
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(case: :lower)
  end

  @doc """
  Generates a random cookie for a distributed node.
  """
  @spec random_cookie() :: atom()
  def random_cookie do
    # credo:disable-for-next-line
    :"c_#{Base.url_encode64(:crypto.strong_rand_bytes(39))}"
  end

  @doc """
  Generates a random binary id that includes node information.

  ## Format

  The id is formed from the following binary parts:

    * 16B - hashed node name
    * 9B - random bytes

  The binary is base32 encoded.
  """
  @spec random_node_aware_id() :: id()
  def random_node_aware_id do
    node_part = node_hash(node())
    random_part = :crypto.strong_rand_bytes(9)
    binary = <<node_part::binary, random_part::binary>>
    # 16B + 9B = 25B is suitable for base32 encoding without padding
    Base.encode32(binary, case: :lower)
  end

  # Note: the result is always 16 bytes long
  defp node_hash(node) do
    content = Atom.to_string(node)
    :erlang.md5(content)
  end

  @doc """
  Extracts node name from the given node aware id.

  The node in question must be connected, otherwise it won't be found.
  """
  @spec node_from_node_aware_id(id()) :: {:ok, node()} | :error
  def node_from_node_aware_id(id) do
    binary = Base.decode32!(id, case: :lower)
    <<node_part::binary-size(16), _random_part::binary-size(9)>> = binary

    known_nodes = [node() | Node.list()]

    Enum.find_value(known_nodes, :error, fn node ->
      node_hash(node) == node_part && {:ok, node}
    end)
  end

  @doc """
  Converts the given name to node identifier.
  """
  @spec node_from_name(String.t()) :: atom()
  def node_from_name(name) do
    if name =~ "@" do
      # credo:disable-for-next-line
      String.to_atom(name)
    else
      # Default to the same host as the current node
      # credo:disable-for-next-line
      :"#{name}@#{node_host()}"
    end
  end

  @doc """
  Returns the host part of a node.
  """
  @spec node_host() :: binary()
  def node_host do
    [_, host] = node() |> Atom.to_string() |> :binary.split("@")
    host
  end

  @doc """
  Registers the given process under `name` for the time of `fun` evaluation.
  """
  @spec temporarily_register(pid(), atom(), (... -> any())) :: any()
  def temporarily_register(pid, name, fun) do
    Process.register(pid, name)
    fun.()
  after
    Process.unregister(name)
  end

  @doc """
  Returns a function that accesses list items by the given id.

  ## Examples

      iex> list = [%{id: 1, name: "Jake"}, %{id: 2, name: "Amy"}]
      iex> get_in(list, [SM.Utils.access_by_id(2), Access.key(:name)])
      "Amy"

      iex> list = [%{id: 1, name: "Jake"}, %{id: 2, name: "Amy"}]
      iex> put_in(list, [SM.Utils.access_by_id(2), Access.key(:name)], "Amy Santiago")
      [%{id: 1, name: "Jake"}, %{id: 2, name: "Amy Santiago"}]

  An error is raised if the accessed structure is not a list:

      iex> get_in(%{}, [SM.Utils.access_by_id(1)])
      ** (RuntimeError) SM.Utils.access_by_id/1 expected a list, got: %{}
  """
  @spec access_by_id(term()) ::
          Access.access_fun(data :: struct() | map(), current_value :: term())
  def access_by_id(id) do
    fn
      :get, data, next when is_list(data) ->
        data
        |> Enum.find(fn item -> item.id == id end)
        |> next.()

      :get_and_update, data, next when is_list(data) ->
        case Enum.split_while(data, fn item -> item.id != id end) do
          {prev, [item | cons]} ->
            # credo:disable-for-next-line
            case next.(item) do
              {get, update} ->
                # credo:disable-for-next-line
                {get, prev ++ [update | cons]}

              :pop ->
                {item, prev ++ cons}
            end

          _other ->
            {nil, data}
        end

      _op, data, _next ->
        raise "SM.Utils.access_by_id/1 expected a list, got: #{inspect(data)}"
    end
  end

  @doc """
  Validates if the given URL is syntactically valid.

  ## Examples

      iex> SM.Utils.valid_url?("not_a_url")
      false

      iex> SM.Utils.valid_url?("https://example.com")
      true

      iex> SM.Utils.valid_url?("http://localhost")
      true

      iex> SM.Utils.valid_url?("http://")
      false
  """
  @spec valid_url?(String.t()) :: boolean()
  def valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme != nil and uri.host not in [nil, ""]
  end

  @doc ~S"""
  Validates if the given string forms valid CLI flags.

  ## Examples

      iex> SM.Utils.valid_cli_flags?("")
      true

      iex> SM.Utils.valid_cli_flags?("--arg1 value --arg2 'value'")
      true

      iex> SM.Utils.valid_cli_flags?("--arg1 \"")
      false
  """
  @spec valid_cli_flags?(String.t()) :: boolean()
  def valid_cli_flags?(flags) do
    _result = OptionParser.split(flags)
    true
  rescue
    _exception -> false
  end

  @doc """
  Changes the first letter in the given string to upper case.

  ## Examples

      iex> SM.Utils.upcase_first("sippin tea")
      "Sippin tea"

      iex> SM.Utils.upcase_first("short URL")
      "Short URL"

      iex> SM.Utils.upcase_first("")
      ""
  """
  @spec upcase_first(String.t()) :: String.t()
  def upcase_first(string) do
    {first, rest} = String.split_at(string, 1)
    String.upcase(first) <> rest
  end

  @doc """
  Changes the first letter in the given string to lower case.

  ## Examples

      iex> SM.Utils.downcase_first("Sippin tea")
      "sippin tea"

      iex> SM.Utils.downcase_first("Short URL")
      "short URL"

      iex> SM.Utils.downcase_first("")
      ""
  """
  @spec downcase_first(String.t()) :: String.t()
  def downcase_first(string) do
    {first, rest} = String.split_at(string, 1)
    String.downcase(first) <> rest
  end

  # @doc """
  # Expands a relative path in terms of the given URL.

  # ## Examples

  #     iex> SM.Utils.expand_url("file:///home/user/lib/file.ex", "../root.ex")
  #     "file:///home/user/root.ex"

  #     iex> SM.Utils.expand_url("https://example.com/lib/file.ex?token=supersecret", "../root.ex")
  #     "https://example.com/root.ex?token=supersecret"
  # """

  # @spec expand_url(String.t(), String.t()) :: String.t()
  # def expand_url(url, relative_path) do
  #   url
  #   |> URI.parse()
  #   |> Map.update!(:path, fn path ->
  #     SM.FileSystem.Utils.resolve_unix_like_path(path, relative_path)
  #   end)
  #   |> URI.to_string()
  # end

  @doc ~S"""
  Wraps the given line into lines that fit in `width` characters.

  Words longer than `width` are not broken apart.

  ## Examples

      iex> SM.Utils.wrap_line("cat on the roof", 7)
      "cat on\nthe\nroof"

      iex> SM.Utils.wrap_line("cat in the cup", 7)
      "cat in\nthe cup"

      iex> SM.Utils.wrap_line("cat in the cup", 2)
      "cat\nin\nthe\ncup"
  """
  @spec wrap_line(String.t(), pos_integer()) :: String.t()
  def wrap_line(line, width) do
    line
    |> String.split()
    |> Enum.reduce({[[]], 0}, fn part, {[group | groups], group_size} ->
      size = String.length(part)

      cond do
        group == [] ->
          {[[part] | groups], size}

        group_size + 1 + size <= width ->
          {[[part, " " | group] | groups], group_size + 1 + size}

        true ->
          {[[part], group | groups], size}
      end
    end)
    |> elem(0)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  @doc """
  Reads file contents and encodes it into a data URL.
  """
  @spec read_as_data_url!(Path.t()) :: String.t()
  def read_as_data_url!(path) do
    content = File.read!(path)
    mime = MIME.from_path(path)
    data = Base.encode64(content)
    "data:#{mime};base64,#{data}"
  end

  @doc """
  Opens the given `url` in the browser.
  """
  @spec browser_open(String.t()) :: :ok
  def browser_open(url) do
    win_cmd_args = ["/c", "start", String.replace(url, "&", "^&")]

    cmd_args =
      case :os.type() do
        {:win32, _} ->
          {"cmd", win_cmd_args}

        {:unix, :darwin} ->
          {"open", [url]}

        {:unix, _} ->
          cond do
            System.find_executable("xdg-open") -> {"xdg-open", [url]}
            # When inside WSL
            System.find_executable("cmd.exe") -> {"cmd.exe", win_cmd_args}
            true -> nil
          end
      end

    :ok =
      case cmd_args do
        {cmd, args} ->
          # credo:disable-for-next-line
          {_result, _exit_status} = System.cmd(cmd, args)
          :ok

        nil ->
          Logger.warning("could not open the browser, no open command found in the system")
      end

    :ok
  end

  @doc """
  Splits the given string at the last occurrence of `pattern`.

  ## Examples

      iex> SM.Utils.split_at_last_occurrence("1,2,3", ",")
      {:ok, "1,2", "3"}

      iex> SM.Utils.split_at_last_occurrence("123", ",")
      :error
  """
  @spec split_at_last_occurrence(String.t(), String.pattern()) ::
          {:ok, left :: String.t(), right :: String.t()} | :error
  def split_at_last_occurrence(string, pattern) when is_binary(string) do
    case :binary.matches(string, pattern) do
      [] ->
        :error

      parts ->
        {start, _} = List.last(parts)
        size = byte_size(string)
        {:ok, binary_part(string, 0, start), binary_part(string, start + 1, size - start - 1)}
    end
  end

  @doc ~S"""
  Finds CR characters and removes leading text in the same line.

  Note that trailing CRs are kept.

  ## Examples

      iex> SM.Utils.apply_rewind("Hola\nHmm\rHey")
      "Hola\nHey"

      iex> SM.Utils.apply_rewind("\rHey")
      "Hey"

      iex> SM.Utils.apply_rewind("Hola\r\nHey\r")
      "Hola\r\nHey\r"
  """
  @spec apply_rewind(String.t()) :: String.t()
  def apply_rewind(text) when is_binary(text) do
    apply_rewind(text, "", "")
  end

  defp apply_rewind(<<?\n, rest::binary>>, acc, line), do: apply_rewind(rest, <<acc::binary, line::binary, ?\n>>, "")

  defp apply_rewind(<<?\r, byte, rest::binary>>, acc, _line) when byte != ?\n, do: apply_rewind(rest, acc, <<byte>>)

  defp apply_rewind(<<byte, rest::binary>>, acc, line), do: apply_rewind(rest, acc, <<line::binary, byte>>)

  defp apply_rewind("", acc, line), do: acc <> line

  @doc ~S"""
  Limits `text` to last `max_lines`.

  Replaces the removed lines with `"..."`.

  ## Examples

      iex> SM.Utils.cap_lines("Line 1\nLine 2\nLine 3\nLine 4", 2)
      "...\nLine 3\nLine 4"

      iex> SM.Utils.cap_lines("Line 1\nLine 2", 2)
      "Line 1\nLine 2"

      iex> SM.Utils.cap_lines("Line 1\nLine 2", 3)
      "Line 1\nLine 2"
  """
  @spec cap_lines(String.t(), non_neg_integer()) :: String.t()
  def cap_lines(text, max_lines) do
    text
    |> :binary.matches("\n")
    |> Enum.at(-max_lines)
    |> case do
      nil ->
        text

      {pos, _len} ->
        <<_ignore::binary-size(pos), rest::binary>> = text
        "..." <> rest
    end
  end

  @spec juror_voting_url(String.t() | URI.t(), String.t(), String.t()) :: String.t()
  def juror_voting_url(base_url \\ SMWeb.Endpoint.access_struct_url(), competition_id, user_id) do
    base_url
    |> URI.parse()
    |> Map.replace!(:path, "/vote/#{competition_id}/#{user_id}")
    |> URI.to_string()
  end

  @doc """
  Formats the given number of bytes into a human-friendly text.

  ## Examples

      iex> SM.Utils.format_bytes(0)
      "0 B"

      iex> SM.Utils.format_bytes(1000)
      "1000 B"

      iex> SM.Utils.format_bytes(1100)
      "1.1 KB"

      iex> SM.Utils.format_bytes(1_228_800)
      "1.2 MB"

      iex> SM.Utils.format_bytes(1_363_148_800)
      "1.3 GB"

      iex> SM.Utils.format_bytes(1_503_238_553_600)
      "1.4 TB"
  """
  @spec format_bytes(integer()) :: nonempty_binary()
  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= memory_unit(:TB) -> format_bytes(bytes, :TB)
      bytes >= memory_unit(:GB) -> format_bytes(bytes, :GB)
      bytes >= memory_unit(:MB) -> format_bytes(bytes, :MB)
      bytes >= memory_unit(:KB) -> format_bytes(bytes, :KB)
      true -> format_bytes(bytes, :B)
    end
  end

  defp format_bytes(bytes, :B) when is_integer(bytes), do: "#{bytes} B"

  defp format_bytes(bytes, unit) when is_integer(bytes) do
    value = bytes / memory_unit(unit)
    "#{:erlang.float_to_binary(value, decimals: 2)} #{unit}"
  end

  defp memory_unit(:TB), do: 1024 * 1024 * 1024 * 1024
  defp memory_unit(:GB), do: 1024 * 1024 * 1024
  defp memory_unit(:MB), do: 1024 * 1024
  defp memory_unit(:KB), do: 1024

  @doc """
  Gets the port for an existing listener.

  The listener references usually follow the pattern `plug.HTTP`
  and `plug.HTTPS`.
  """
  @spec get_port(module, :http | :https, :inet.port_number()) :: :inet.port_number()
  def get_port(endpoint, scheme, default) do
    {:ok, pid} = Bandit.PhoenixAdapter.bandit_pid(endpoint, scheme)
    ThousandIsland.listener_info(pid)
  rescue
    _exception -> default
  else
    {:ok, {_, port}} when is_integer(port) -> port
    _other -> default
  end

  @doc """
  Converts the given IP address into a valid hostname.

  ## Examples

      iex> SM.Utils.ip_to_host({192, 168, 0, 1})
      "192.168.0.1"

      iex> SM.Utils.ip_to_host({127, 0, 0, 1})
      "localhost"

      iex> SM.Utils.ip_to_host({0, 0, 0, 0})
      "localhost"
  """
  @spec ip_to_host(:inet.ip_address()) :: String.t()
  def ip_to_host(ip)

  def ip_to_host({0, 0, 0, 0}), do: "localhost"
  def ip_to_host({127, 0, 0, 1}), do: "localhost"

  def ip_to_host(ip) do
    ip |> :inet.ntoa() |> List.to_string()
  end
end
