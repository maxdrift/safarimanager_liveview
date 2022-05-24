defmodule SM.MixProject do
  use Mix.Project

  def project do
    [
      app: :safarimanager,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers() ++ [:surface],
      start_permanent: Mix.env() in [:prod, :standalone],
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      releases: releases(),
      preferred_cli_env: [release: :standalone],
      dialyzer_ignored_warnings: dialyzer_ignored_warnings()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SM.Application, []},
      extra_applications: [:logger, :runtime_tools, :mogrify]
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
      {:bcrypt_elixir, "~> 2.0"},
      {:bakeware, "~> 0.2.3", runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyzex, "~> 1.3.0", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:ecto_sqlite3, "~> 0.7.4"},
      {:esbuild, "~> 0.3", runtime: Mix.env() == :dev},
      {:exexif, "~> 0.0.5"},
      {:gettext, "~> 0.19"},
      {:jason, "~> 1.2"},
      {:mogrify, "~> 0.9.1"},
      {:nimble_csv, "~> 1.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.9"},
      {:phoenix, "~> 1.6.5"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:random_password, "~> 1.0"},
      {:rexbug, "~> 1.0"},
      {:surface_catalogue, "~> 0.3.0"},
      {:surface, "~> 0.7.1"},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"}
    ]
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
      ],
      "release.standalone": ["assets.deploy", "release"]
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
    case Mix.env() do
      :standalone ->
        [
          safarimanager: [
            steps: [:assemble, &Bakeware.assemble/1],
            overwrite: true,
            strip_beams: true
          ]
        ]

      :prod ->
        [
          safarimanager: [
            include_executables_for: [:unix],
            applications: [safarimanager: :permanent],
            strip_beams: true,
            include_erts: true
          ]
        ]

      _other_env ->
        [
          safarimanager: [
            strip_beams: false
          ]
        ]
    end
  end

  defp dialyzer_ignored_warnings do
    [
      {:_, {'deps/nimble_csv/lib/nimble_csv.ex', 523}, {:_, :_}},
      {:_, {'lib/safarimanager/default_password.ex', 5}, {:_, :_}}
    ]
  end
end
