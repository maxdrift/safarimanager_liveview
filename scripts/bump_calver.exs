# Bump CalVer across mix.exs and Tauri manifests: @version / Cargo.toml / Cargo.lock / tauri.conf.json
# Format: YY.M.S (two-digit calendar year, month, sequence within that month; no leading zeros)
#
# Compares the version in mix.exs with today's local date (OS timezone):
# - Same YY and month: increment seq.
# - Different YY or month: set to today's YY.M with seq 1.
#
# The first segment may still be a legacy four-digit year (e.g. 2026); it is normalized to YY (26)
# for comparison and for the written version.
#
# Usage (from repo root): elixir scripts/bump_calver.exs

{{cur_y, cur_m, _}, _} = :calendar.local_time()
cur_yy = rem(cur_y, 100)

normalize_year_segment = fn ys ->
  y = String.to_integer(ys)
  if y >= 100, do: rem(y, 100), else: y
end

mix_path = "mix.exs"
content = File.read!(mix_path)

case Regex.run(~r/@version "(\d+)\.(\d+)\.(\d+)"/, content) do
  [_, ys, ms, seqs] ->
    file_yy = normalize_year_segment.(ys)
    file_m = String.to_integer(ms)
    file_seq = String.to_integer(seqs)

    {new_yy, new_m, new_seq} =
      if file_yy == cur_yy && file_m == cur_m do
        {cur_yy, cur_m, file_seq + 1}
      else
        {cur_yy, cur_m, 1}
      end

    new_v = "#{new_yy}.#{new_m}.#{new_seq}"

    new_mix =
      Regex.replace(
        ~r/(@version ")\d+\.\d+\.\d+(")/,
        content,
        fn _, open, close -> open <> new_v <> close end,
        global: false
      )

    File.write!(mix_path, new_mix)

    tauri_conf_path = "src-tauri/tauri.conf.json"
    tauri_conf = File.read!(tauri_conf_path)

    new_tauri =
      Regex.replace(
        ~r/("version": ")\d+\.\d+\.\d+(")/,
        tauri_conf,
        fn _, open, close -> open <> new_v <> close end,
        global: false
      )

    File.write!(tauri_conf_path, new_tauri)

    cargo_path = "src-tauri/Cargo.toml"
    cargo = File.read!(cargo_path)

    new_cargo =
      Regex.replace(
        ~r/(name = "safarimanager_desktop"\Rversion = ")\d+\.\d+\.\d+(")/,
        cargo,
        fn _, open, close -> open <> new_v <> close end
      )

    File.write!(cargo_path, new_cargo)

    lock_path = "src-tauri/Cargo.lock"
    lock = File.read!(lock_path)

    new_lock =
      Regex.replace(
        ~r/(\[\[package\]\]\Rname = "safarimanager_desktop"\Rversion = ")\d+\.\d+\.\d+(")/,
        lock,
        fn _, open, close -> open <> new_v <> close end
      )

    File.write!(lock_path, new_lock)

    IO.puts(new_v)

  _ ->
    IO.puts(:stderr, ~s'Could not find @version "YY.M.S" (dot-separated integers) in mix.exs')
    System.halt(1)
end
