defmodule SM.RepoBusyRetryTest do
  use ExUnit.Case, async: true

  alias SM.Repo

  defmodule BusyError do
    @moduledoc false
    defexception [:message]
  end

  test "retries raised Database busy then returns success" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    result =
      Repo.with_busy_retry(
        fn ->
          count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

          if count < 2 do
            raise BusyError, message: "Database busy"
          else
            {:ok, :done}
          end
        end,
        max_attempts: 5
      )

    assert result == {:ok, :done}
    assert Agent.get(agent, & &1) == 3
  end

  test "retries {:error, busy} tuples then returns success" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    result =
      Repo.with_busy_retry(
        fn ->
          count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

          if count < 2 do
            {:error, %BusyError{message: "Database busy\nINSERT INTO slides"}}
          else
            {:ok, :inserted}
          end
        end,
        max_attempts: 5
      )

    assert result == {:ok, :inserted}
  end

  test "reraises non-busy errors" do
    assert_raise BusyError, "boom", fn ->
      Repo.with_busy_retry(fn -> raise BusyError, message: "boom" end, max_attempts: 3)
    end
  end

  test "exhausts attempts on persistent busy" do
    assert_raise BusyError, ~r/Database busy/, fn ->
      Repo.with_busy_retry(
        fn -> raise BusyError, message: "Database busy" end,
        max_attempts: 3
      )
    end
  end
end
