# Bump CalVer in mix.exs: @version "Y.M.S" (year.month.seq, no leading zeros)
#
# Compares the version period in mix.exs with today's local date (OS timezone):
# - Same year and month: increment seq.
# - Different year or month: set to today's YYYY.MM with seq 1.
#
# Usage: elixir scripts/bump_calver.exs

{{cur_y, cur_m, _}, _} = :calendar.local_time()

content = File.read!("mix.exs")

case Regex.run(~r/@version "(\d+)\.(\d+)\.(\d+)"/, content) do
  [_, ys, ms, seqs] ->
    file_y = String.to_integer(ys)
    file_m = String.to_integer(ms)
    file_seq = String.to_integer(seqs)

    {new_y, new_m, new_seq} =
      if file_y == cur_y && file_m == cur_m do
        {cur_y, cur_m, file_seq + 1}
      else
        {cur_y, cur_m, 1}
      end

    new_v = "#{new_y}.#{new_m}.#{new_seq}"

    # Replacement must be a function: a string repl would treat "\\1" + "2026..." as "\\12...".
    new_content =
      Regex.replace(
        ~r/(@version ")\d+\.\d+\.\d+(")/,
        content,
        fn _, open, close -> open <> new_v <> close end,
        global: false
      )

    File.write!("mix.exs", new_content)
    IO.puts(new_v)

  _ ->
    IO.puts(:stderr, ~s'Could not find @version "Y.M.S" (dot-separated integers) in mix.exs')
    System.halt(1)
end
