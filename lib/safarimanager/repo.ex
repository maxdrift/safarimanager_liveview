defmodule SM.Repo do
  use Ecto.Repo,
    otp_app: :safarimanager,
    # adapter: if(Mix.env() == :prod, do: Ecto.Adapters.Postgres, else: Ecto.Adapters.SQLite3)
    adapter: Ecto.Adapters.SQLite3

  use EctoCursorBasedStream

  @doc """
  Runs `fun` and retries when SQLite reports `Database busy`.

  Prefer short transactions around this; `busy_timeout` on the connection is the
  first line of defense, retries cover stampede tails.
  """
  @spec with_busy_retry((-> result), keyword()) :: result when result: var
  def with_busy_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_attempts = Keyword.get(opts, :max_attempts, 8)
    do_with_busy_retry(fun, 1, max_attempts)
  end

  defp do_with_busy_retry(fun, attempt, max_attempts) do
    case fun.() do
      {:error, reason} = error ->
        if database_busy?(reason) and attempt < max_attempts do
          busy_backoff(attempt)
          do_with_busy_retry(fun, attempt + 1, max_attempts)
        else
          error
        end

      other ->
        other
    end
  rescue
    error ->
      if database_busy?(error) and attempt < max_attempts do
        busy_backoff(attempt)
        do_with_busy_retry(fun, attempt + 1, max_attempts)
      else
        reraise error, __STACKTRACE__
      end
  catch
    :throw, {:error, reason} = error ->
      if database_busy?(reason) and attempt < max_attempts do
        busy_backoff(attempt)
        do_with_busy_retry(fun, attempt + 1, max_attempts)
      else
        throw(error)
      end
  end

  defp busy_backoff(attempt) do
    Process.sleep(25 * attempt + :rand.uniform(25))
  end

  defp database_busy?(%{message: message}) when is_binary(message) do
    String.contains?(String.downcase(message), "database busy")
  end

  defp database_busy?(message) when is_binary(message) do
    String.contains?(String.downcase(message), "database busy")
  end

  defp database_busy?(other) when is_exception(other) do
    String.contains?(String.downcase(Exception.message(other)), "database busy")
  end

  defp database_busy?(_), do: false
end
