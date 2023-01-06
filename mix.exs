defmodule SM.MixProject do
  use Mix.Project

  @elixir_requirement "~> 1.14"
  @version "0.1.2"
  @description ~s(Application to manage "Underwater Photo Safari" competitions)

  @app_elixir_version "1.14.2"
  @app_rebar3_version "3.19.0"

  def project do
    [
      app: :safarimanager,
      version: @version,
      elixir: @elixir_requirement,
      name: "SafariManager",
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:surface],
      start_permanent: Mix.env() in [:prod, :standalone],
      aliases: aliases(),
      deps: with_lock(target_deps(Mix.target()) ++ deps()),
      dialyzer: dialyzer(),
      releases: releases(),
      preferred_cli_env: preferred_cli_env(),
      preferred_cli_target: preferred_cli_target(),
      default_release: :safarimanager,
      # Adding this explicit list to account for the `race_conditions` warning being removed in OTP 25
      # https://www.erlang.org/patches/otp-25.0#dialyzer-5.0
      dialyzer_warnings: [:unmatched_returns, :error_handling, :underspecs, :unknown],
      dialyzer_ignored_warnings: dialyzer_ignored_warnings()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SM.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :inets, :ssl, :xmerl],
      env: Application.get_all_env(:safarimanager)
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib"] ++ catalogues()
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyzex, "~> 1.3.0", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.9"},
      {:ecto_sqlite3, "~> 0.9.0"},
      {:esbuild, "~> 0.6", runtime: Mix.env() == :dev},
      {:finch, "~> 0.14.0", override: true},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.19"},
      {:heroicons, "~> 0.5"},
      {:image, "~> 0.15"},
      {:jason, "~> 1.2"},
      {:nimble_csv, "~> 1.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.2"},
      {:phoenix_live_reload, "~> 1.4.1", only: :dev},
      {:phoenix_live_view, "~> 0.18.3"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix, "~> 1.7.0-rc.0", override: true},
      {:plug_cowboy, "~> 2.6", override: true},
      {:postgrex, ">= 0.0.0"},
      {:prom_ex, "~> 1.7"},
      {:random_password, "~> 1.0"},
      {:rexbug, "~> 1.0"},
      {:surface_catalogue, "~> 0.5"},
      {:surface, "~> 0.9.1"},
      {:swoosh, "~> 1.9.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry, "~> 1.1", override: true},
      {:tesla, "~> 1.4"}
    ]
  end

  defp target_deps(:app), do: [{:elixirkit, path: "elixirkit"}]
  defp target_deps(_), do: []

  @lock (with {:ok, contents} <- File.read("mix.lock"),
              {:ok, quoted} <- Code.string_to_quoted(contents, warn_on_unnecessary_quotes: false),
              {%{} = lock, _binding} <- Code.eval_quoted(quoted, []) do
           for {dep, hex} when elem(hex, 0) == :hex <- lock,
               do: {dep, elem(hex, 2)},
               into: %{}
         else
           _ -> %{}
         end)

  defp with_lock(deps) do
    for dep <- deps do
      name = elem(dep, 0)
      put_elem(dep, 1, @lock[name] || elem(dep, 1))
    end
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd --cd assets yarn"],
      # "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["cmd --cd assets yarn run deploy"],
      "assets.esbuild": ["esbuild default --minify"],
      release: [
        "assets.esbuild",
        "phx.digest priv/static",
        "release",
        "phx.digest.clean --all"
      ]
    ]
  end

  def catalogues do
    [
      "priv/catalogue"
    ]
  end

  defp dialyzer do
    [
      flags: [:error_handling, :race_conditions, :underspecs],
      plt_add_apps: [:ex_unit, :mix]
    ]
  end

  defp releases do
    macos_notarization = macos_notarization()

    additional_paths = [
      "vendor/otp/erts-#{:erlang.system_info(:version)}/bin",
      "vendor/otp/bin",
      "vendor/elixir/bin"
    ]

    [
      safarimanager: [
        include_executables_for: [:unix],
        applications: [safarimanager: :permanent],
        strip_beams: true,
        include_erts: true
      ],
      app: [
        include_erts: false,
        rel_templates_path: "rel/app",
        steps: [
          :assemble,
          &remove_cookie/1,
          &standalone_erlang_elixir/1,
          &ElixirKit.bundle/1
        ],
        app: [
          launcher_path: "rel/app/Launcher.swift",
          info_plist_path: "rel/app/Info.plist.eex",
          resources: %{
            "AppIcon.icns" => "rel/app/icon-macos.icns",
            "Icon.svg" => "rel/app/icon.svg"
          },
          root_dir: "vendor/otp",
          additional_paths: additional_paths ++ ["/usr/local/bin"],
          build_dmg: macos_notarization != nil,
          notarization: macos_notarization
        ]
      ]
    ]
  end

  defp dialyzer_ignored_warnings do
    [
      {:_, {'deps/nimble_csv/lib/nimble_csv.ex', 523}, {:_, :_}},
      {:_, {'lib/safarimanager/default_password.ex', 5}, {:_, :_}}
    ]
  end

  defp macos_notarization do
    identity = System.get_env("NOTARIZE_IDENTITY")
    team_id = System.get_env("NOTARIZE_TEAM_ID")
    apple_id = System.get_env("NOTARIZE_APPLE_ID")
    password = System.get_env("NOTARIZE_PASSWORD")

    if identity do
      [
        identity: identity,
        team_id: team_id,
        apple_id: apple_id,
        password: password,
        entitlements_plist_path: "rel/app/Entitlements.plist"
      ]
    end
  end

  defp remove_cookie(release) do
    File.rm!(Path.join(release.path, "releases/COOKIE"))
    release
  end

  defp standalone_erlang_elixir(release) do
    Code.require_file("rel/app/standalone.exs")

    release
    |> Standalone.copy_otp()
    |> Standalone.copy_elixir(@app_elixir_version)
    |> Standalone.copy_hex()
    |> Standalone.copy_rebar3(@app_rebar3_version)
    |> Standalone.bundle_dylibs()
  end

  defp preferred_cli_env do
    [
      app: :prod,
      "app.build": :prod
    ]
  end

  defp preferred_cli_target do
    [
      app: :app,
      "app.build": :app
    ]
  end
end
