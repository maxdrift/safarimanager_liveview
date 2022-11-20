defmodule SM.MixProject do
  use Mix.Project

  @elixir_requirement "~> 1.14"
  @version "0.1.2"
  @description "Application to manage photographic 'Safari' competitions"

  @app_elixir_version "1.14.0"
  @app_rebar3_version "3.19.0"

  def project do
    [
      app: :safarimanager,
      version: @version,
      elixir: @elixir_requirement,
      name: "Safari Manager",
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:surface],
      start_permanent: Mix.env() in [:prod, :standalone],
      aliases: aliases(),
      deps: with_lock(target_deps(Mix.target()) ++ deps()),
      dialyzer: dialyzer(),
      releases: releases(),
      dialyzer_ignored_warnings: dialyzer_ignored_warnings()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SM.Application, []},
      extra_applications: [:logger, :runtime_tools, :mogrify] ++ extra_applications(Mix.target()),
      env: Application.get_all_env(:safarimanager)
    ]
  end

  defp extra_applications(:app), do: [:wx]
  defp extra_applications(_), do: []

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
      {:ecto_sqlite3, "~> 0.8.2"},
      {:esbuild, "~> 0.3", runtime: Mix.env() == :dev},
      {:exexif, "~> 0.0.5"},
      {:finch, "~> 0.13.0", override: true},
      {:gettext, "~> 0.19"},
      {:jason, "~> 1.2"},
      {:mogrify, "~> 0.9.1"},
      {:nimble_csv, "~> 1.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.2"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 0.18.3"},
      {:phoenix, "~> 1.6.15"},
      {:plug_cowboy, "~> 2.6", override: true},
      {:postgrex, ">= 0.0.0"},
      {:prom_ex, "~> 1.7"},
      {:random_password, "~> 1.0"},
      {:rexbug, "~> 1.0"},
      {:surface_catalogue, "~> 0.5"},
      {:surface, "~> 0.9.1"},
      {:swoosh, "~> 1.8"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry, "~> 1.1", override: true},
      {:tesla, "~> 1.4"}
    ]
  end

  defp target_deps(:app), do: [{:app_bundler, path: "../app_bundler"}]
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
          &AppBundler.bundle/1
        ],
        app: [
          name: "SafariManager",
          url_schemes: ["safarimanager"],
          document_types: [
            [
              name: "SafariManagerData",
              extensions: ["smgr"],
              macos: [
                icon_path: "rel/app/icon.png",
                role: "Editor"
              ],
              windows: [
                icon_path: "rel/app/icon.ico"
              ]
            ]
          ],
          additional_paths: [
            "rel/erts-#{:erlang.system_info(:version)}/bin",
            "rel/vendor/elixir/bin"
          ],
          macos: [
            app_type: :agent,
            icon_path: "rel/app/icon-macos.png",
            build_dmg: macos_notarization() != nil,
            notarization: macos_notarization()
          ],
          windows: [
            icon_path: "rel/app/icon.ico",
            build_installer: true
          ]
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

    if identity && team_id && apple_id && password do
      [identity: identity, team_id: team_id, apple_id: apple_id, password: password]
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
  end
end
