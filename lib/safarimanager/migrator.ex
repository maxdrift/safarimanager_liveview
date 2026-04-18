# credo:disable-for-this-file
defmodule SM.Migrator do
  @moduledoc """
  Migration script from the OLD MS Access Safari Manager app to the new Elixir Safari Manager.
  """

  alias Exqlite.Basic

  require Logger

  @similarity_threshold 0.8
  @progressbar_format [bar: "█", bar_color: IO.ANSI.green()]

  @spec migrate_databases(String.t()) :: :ok
  def migrate_databases(search_path \\ "/Volumes/1TB-T7/**/database*.db") do
    paths = Path.wildcard(search_path)
    paths_count = Enum.count(paths)

    _result =
      Enum.with_index(paths, fn path, idx ->
        Logger.debug("Migrating DB #{idx + 1} of #{paths_count}")
        ProgressBar.render(idx + 1, paths_count, @progressbar_format)
        migrate_database(path)
      end)

    :ok
  end

  @spec migrate_database(String.t()) ::
          :ok | {:error, :db_connection_failed | String.t() | Exqlite.Error.t()}
  def migrate_database(path) do
    with {:ok, conn} <- connect_to_db(path),
         :ok <- migrate_tables(conn, %{}),
         do: disconnect_from_db(conn)
  end

  # Internal

  defp migrate_tables(conn, accumulator) do
    with {:ok, version} <- determine_version(conn),
         :ok <- Logger.debug("determined version: #{version}"),
         {:ok, accumulator} <- migrate_organizations(conn, accumulator, version),
         :ok <- Logger.debug("migrated organizations (#{version})"),
         {:ok, accumulator} <- migrate_subjects(conn, accumulator, version),
         :ok <- Logger.debug("migrated subjects (#{version})"),
         {:ok, accumulator} <- migrate_categories(conn, accumulator, version),
         :ok <- Logger.debug("migrated categories (#{version})"),
         {:ok, accumulator} <- migrate_coefficients(conn, accumulator, version),
         :ok <- Logger.debug("migrated coefficients (#{version})"),
         {:ok, accumulator} <- migrate_users(conn, accumulator, version),
         :ok <- Logger.debug("migrated users (#{version})"),
         {:ok, accumulator} <- migrate_competitions(conn, accumulator, version),
         :ok <- Logger.debug("migrated competitions (#{version})"),
         {:ok, accumulator} <- migrate_participants(conn, accumulator, version),
         :ok <- Logger.debug("migrated participants (#{version})"),
         {:ok, accumulator} <- migrate_jurors(conn, accumulator, version),
         :ok <- Logger.debug("migrated jurors (#{version})"),
         {:ok, _accumulator} <- migrate_slides(conn, accumulator, version),
         :ok <- Logger.debug("migrated slides (#{version})") do
      :ok
    else
      {:error, :existing_competition} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def determine_version(conn) do
    cond do
      has_id_societa?(conn) and has_coefficients?(conn) -> {:ok, :v3}
      has_id_societa?(conn) -> {:ok, :v2}
      true -> {:ok, :v1}
    end
  end

  defp has_id_societa?(conn) do
    conn |> Basic.exec("select ID_societa from iscritti") |> Basic.rows() !=
      {:error, "no such column: ID_societa"}
  end

  defp has_coefficients?(conn) do
    conn |> Basic.exec("select * from coefficients") |> Basic.rows() !=
      {:error, "no such table: coefficients"}
  end

  defp migrate_organizations(conn, accumulator, _version) do
    with {:ok, societa} <- get_table_data(conn, :societa) do
      pre_existing = SM.Organizations.list()

      organizations =
        Map.new(societa, fn {key, row} ->
          new_row =
            row
            |> get_or_create(:nomes, :name, pre_existing, @similarity_threshold)
            |> case do
              {:ok, :create} ->
                {:ok, new_record} = SM.Organizations.create(%{name: row.nomes, location: row.luogos})

                new_record

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :societa, Map.new(societa))
      accumulator = Map.put(accumulator, :organizations, organizations)
      {:ok, accumulator}
    end
  end

  defp migrate_subjects(conn, accumulator, :v1) do
    with {:ok, pesci} <- get_table_data(conn, :elencop, [:*], :nump) do
      pre_existing = SM.Subjects.list()

      max_numeric_id =
        pre_existing
        |> Enum.max_by(& &1.numeric_id)
        |> Map.fetch!(:numeric_id)

      subjects =
        Map.new(pesci, fn {key, row} ->
          new_row =
            row
            |> get_or_create(:nomep, :name, pre_existing, @similarity_threshold)
            |> case do
              {:ok, :create} ->
                {:ok, new_record} =
                  SM.Subjects.create(%{
                    name: String.downcase(row.nomep),
                    coefficient: row.coeff,
                    numeric_id: Enum.random(max_numeric_id..160),
                    scientific_name: String.downcase(Map.get(row, :nome_scientifico) || ""),
                    type: :fish
                  })

                new_record

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :pesci, Map.new(pesci))
      accumulator = Map.put(accumulator, :subjects, subjects)
      {:ok, accumulator}
    end
  end

  defp migrate_subjects(conn, accumulator, _version) do
    with {:ok, pesci} <- get_table_data(conn, :pesci) do
      pre_existing = SM.Subjects.list()

      subjects =
        Map.new(pesci, fn {key, row} ->
          new_row =
            row
            |> get_or_create(:nome, :name, pre_existing, @similarity_threshold)
            |> case do
              {:ok, :create} ->
                {:ok, new_record} =
                  SM.Subjects.create(%{
                    name: String.downcase(row.nome),
                    coefficient: row.coeff,
                    numeric_id: 160 + row."ID" + Enum.random(0..160),
                    scientific_name: String.downcase(Map.get(row, :nome_scientifico) || ""),
                    type: :fish
                  })

                new_record

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :pesci, Map.new(pesci))
      accumulator = Map.put(accumulator, :subjects, subjects)
      {:ok, accumulator}
    end
  end

  defp migrate_categories(conn, accumulator, _version) do
    with {:ok, categorie} <- get_table_data(conn, :categorie) do
      pre_existing = SM.Categories.list()

      categories =
        Map.new(categorie, fn {key, row} ->
          new_row =
            row
            |> get_or_create(:categoria, :name, pre_existing, @similarity_threshold)
            |> case do
              {:ok, :create} ->
                {:ok, new_record} = SM.Categories.create(%{name: row.categoria})

                new_record

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :categorie, Map.new(categorie))
      accumulator = Map.put(accumulator, :categories, categories)
      {:ok, accumulator}
    end
  end

  defp migrate_coefficients(conn, accumulator, :v3) do
    with {:ok, coefficienti} <- get_table_data(conn, :coefficienti) do
      coefficients =
        coefficienti
        |> Stream.reject(fn {_key, coeff} -> coeff.grado == "null" end)
        |> Map.new(fn {key, row} ->
          new_row =
            row
            |> get_or_create(nil, nil, [], @similarity_threshold)
            |> case do
              {:ok, :create} ->
                %{
                  name: row.grado,
                  value: Decimal.to_string(Decimal.new(row.valore)),
                  from: Decimal.to_string(Decimal.div(row.soglia_inf, 100)),
                  to: Decimal.to_string(Decimal.div(row.soglia_sup, 100))
                }

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :coefficienti, Map.new(coefficienti))
      accumulator = Map.put(accumulator, :coefficients, coefficients)
      {:ok, accumulator}
    end
  end

  defp migrate_coefficients(_conn, accumulator, _version) do
    accumulator = Map.put(accumulator, :coefficienti, %{})
    accumulator = Map.put(accumulator, :coefficients, %{})
    {:ok, accumulator}
  end

  defp migrate_users(conn, accumulator, :v1) do
    with {:ok, iscritti} <- get_table_data(conn, :iscritti, [:*], :letterac) do
      pre_existing = SM.Accounts.list()

      users =
        Map.new(iscritti, fn {key, row} ->
          new_row =
            row
            |> get_or_create([:cognomec, :nomec], [:last_name, :first_name], pre_existing, 0.9)
            |> case do
              {:ok, :create} ->
                org_old_id =
                  accumulator
                  |> Map.fetch!(:societa)
                  |> Enum.find_value(fn {pk, s} -> if s.nomes == row.nomes, do: pk end)

                org_id = accumulator |> Map.fetch!(:organizations) |> Map.fetch!(org_old_id) |> Map.fetch!(:id)

                category_old_id =
                  accumulator
                  |> Map.fetch!(:categorie)
                  |> Enum.find_value(fn {pk, s} -> if s.categoria == row.categoria, do: pk end)

                category_id = accumulator |> Map.fetch!(:categories) |> Map.fetch!(category_old_id) |> Map.fetch!(:id)

                {:ok, new_record} =
                  SM.Accounts.register_simplified_user(%{
                    first_name: row.nomec,
                    last_name: row.cognomec,
                    organization_id: org_id,
                    category_id: category_id
                  })

                new_record

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :iscritti, Map.new(iscritti))
      accumulator = Map.put(accumulator, :users, users)
      {:ok, accumulator}
    end
  end

  defp migrate_users(conn, accumulator, _version) do
    with {:ok, iscritti} <- get_table_data(conn, :iscritti, [:*], :ID) do
      pre_existing = SM.Accounts.list()

      users =
        Map.new(iscritti, fn {key, row} ->
          new_row =
            row
            |> get_or_create([:cognome, :nome], [:last_name, :first_name], pre_existing, 0.9)
            |> case do
              {:ok, :create} ->
                org_id = accumulator |> Map.fetch!(:organizations) |> Map.fetch!(row."ID_societa") |> Map.fetch!(:id)

                category_id = accumulator |> Map.fetch!(:categories) |> Map.fetch!(row."ID_categoria") |> Map.fetch!(:id)

                {:ok, new_record} =
                  SM.Accounts.register_simplified_user(%{
                    first_name: row.nome,
                    last_name: row.cognome,
                    organization_id: org_id,
                    category_id: category_id
                  })

                new_record

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :iscritti, Map.new(iscritti))
      accumulator = Map.put(accumulator, :users, users)
      {:ok, accumulator}
    end
  end

  defp migrate_competitions(conn, accumulator, _version) do
    with {:ok, gara} <- get_table_data(conn, :gara, [:*], :id) do
      pre_existing = SM.Competitions.list()

      [competition] =
        gara
        |> Stream.map(fn {_key, row} ->
          row
          |> get_or_create(
            [:denom, :data],
            [:name, fn r -> r.start_time && DateTime.to_date(r.start_time) end],
            pre_existing,
            1.0
          )
          |> case do
            {:ok, :create} ->
              all_orgs =
                accumulator
                |> Map.fetch!(:organizations)
                |> Enum.map(fn {_key, org} -> org end)

              org_id =
                %{nomes: row.organizz}
                |> get_or_create(:nomes, :name, all_orgs, 0.8)
                |> case do
                  {:ok, :create} ->
                    {:ok, new_record} =
                      SM.Organizations.create(%{
                        name: row.organizz
                      })

                    new_record.id

                  {:ok, existing} ->
                    existing.id
                end

              dynamic_coefficients =
                accumulator
                |> Map.fetch!(:coefficients)
                |> Enum.map(fn {_id, value} -> value end)

              dynamic_coefficients_enabled? =
                Enum.any?(dynamic_coefficients, fn dc -> !Decimal.equal?(dc.value, 1) end)

              percentuale = Map.get(row, :percentuale) || 0
              pspeciep = Map.get(row, :pspeciep) || 1
              moltpuntfisso = Map.get(row, :moltpuntfisso) || 5

              all_evaluations = Enum.map(SM.Evaluations.list(), &%{evaluation_id: &1.id})

              {:ok, competition} =
                SM.Competitions.create(%{
                  name: row.denom,
                  start_time: "#{row.data} 00:00:00",
                  end_time: "#{row.data} 23:59:59",
                  street_name: nil,
                  street_number: nil,
                  postal_code: nil,
                  city: row.luogo,
                  state: nil,
                  country: "Italy",
                  organization_id: org_id,
                  type: :other,
                  competitions_evaluations: all_evaluations,
                  settings: %{
                    evaluations_per_juror: 1,
                    number_of_jurors: 3,
                    max_jury_slides: row.nspeciep,
                    max_submitted_slides: row.totspecie,
                    proportional_submission: if(percentuale == -1, do: true, else: false),
                    submission_ratio: Decimal.div(pspeciep, 100),
                    fixed_points_multiplier: Decimal.new(moltpuntfisso),
                    submission_bonus_per_slide: Decimal.new(0),
                    penalty_amount: Decimal.negate(Decimal.new(row.penalty)),
                    dynamic_coefficients_enabled: dynamic_coefficients_enabled?,
                    coefficient_mode: :all_slides,
                    dynamic_coefficient_mode: (dynamic_coefficients_enabled? && :all) || :disabled,
                    dynamic_coefficients: dynamic_coefficients
                  }
                })

              competition

            {:ok, _existing} ->
              :skip
          end
        end)
        |> Enum.to_list()

      case competition do
        :skip ->
          {:error, :existing_competition}

        competition ->
          accumulator = Map.put(accumulator, :gara, Map.new(gara))
          accumulator = Map.put(accumulator, :competition, competition)
          {:ok, accumulator}
      end
    end
  end

  defp migrate_participants(conn, accumulator, :v1) do
    with {:ok, iscritti} <- get_table_data(conn, :iscritti, [:*], :letterac) do
      participants =
        Map.new(iscritti, fn {key, row} ->
          new_row =
            row
            |> get_or_create(nil, nil, [], @similarity_threshold)
            |> case do
              {:ok, :create} ->
                user_id = accumulator |> Map.fetch!(:users) |> Map.fetch!(row.letterac) |> Map.fetch!(:id)

                competition_id = accumulator |> Map.fetch!(:competition) |> Map.fetch!(:id)

                category_old_id =
                  accumulator
                  |> Map.fetch!(:categorie)
                  |> Enum.find_value(fn {pk, s} -> if s.categoria == row.categoria, do: pk end)

                category_id = accumulator |> Map.fetch!(:categories) |> Map.fetch!(category_old_id) |> Map.fetch!(:id)

                {:ok, new_record} =
                  SM.Participants.create(%{
                    user_id: user_id,
                    competition_id: competition_id,
                    category_id: category_id,
                    number: String.to_integer(row.numgara)
                  })

                new_record

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :participants, participants)
      {:ok, accumulator}
    end
  end

  defp migrate_participants(conn, accumulator, _version) do
    with {:ok, iscritti} <- get_table_data(conn, :iscritti, [:*], :ID) do
      participants =
        Map.new(iscritti, fn {key, row} ->
          new_row =
            row
            |> get_or_create(nil, nil, [], @similarity_threshold)
            |> case do
              {:ok, :create} ->
                user_id = accumulator |> Map.fetch!(:users) |> Map.fetch!(row."ID") |> Map.fetch!(:id)

                competition_id = accumulator |> Map.fetch!(:competition) |> Map.fetch!(:id)

                category_id = accumulator |> Map.fetch!(:categories) |> Map.fetch!(row."ID_categoria") |> Map.fetch!(:id)

                {:ok, _participant} =
                  SM.Participants.create(%{
                    user_id: user_id,
                    competition_id: competition_id,
                    category_id: category_id,
                    number: row."ID"
                  })

                row.nomecartella

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :participants, participants)
      {:ok, accumulator}
    end
  end

  defp migrate_jurors(_conn, accumulator, _version) do
    for i <- 1..3 do
      case SM.Accounts.register_simplified_user(%{first_name: "Giurato #{i}", last_name: "Anonimo"}) do
        {:ok, _user} ->
          :ok

        {:error,
         %Ecto.Changeset{
           errors: [email: {"has already been taken", [constraint: :unique, constraint_name: "users_email_index"]}],
           valid?: false
         }} ->
          :ok
      end
    end

    competition_id =
      accumulator
      |> Map.fetch!(:competition)
      |> Map.fetch!(:id)

    jurors =
      competition_id
      |> SM.Accounts.list_enrollable_jurors("Anonimo")
      |> Enum.sort_by(& &1.first_name, :asc)
      |> Enum.map(fn user ->
        {:ok, juror} =
          SM.Jurors.create(%{
            user_id: user.id,
            competition_id: competition_id
          })

        juror
      end)

    accumulator = Map.put(accumulator, :jurors, jurors)
    {:ok, accumulator}
  end

  defp migrate_slides(conn, accumulator, :v1) do
    with {:ok, slide} <- get_table_data(conn, :slide, [:*], :id) do
      slides =
        Map.new(slide, fn {key, row} ->
          new_row =
            row
            |> get_or_create(nil, nil, [], @similarity_threshold)
            |> case do
              {:ok, :create} ->
                user_id = accumulator |> Map.fetch!(:users) |> Map.fetch!(row.letterac) |> Map.fetch!(:id)

                competition_id = accumulator |> Map.fetch!(:competition) |> Map.fetch!(:id)

                source_path = conn |> Map.fetch!(:directory) |> Path.join(row.path) |> String.replace("\\", "/")

                file_name = Path.basename(source_path)
                %File.Stat{size: file_size} = File.stat!(source_path)

                {:ok, slide} =
                  SM.Slides.create_and_store_slide_file(
                    competition_id,
                    user_id,
                    file_name,
                    file_size,
                    "image/jpeg",
                    source_path
                  )

                subject_id = accumulator |> Map.fetch!(:subjects) |> Map.fetch!(row.nump) |> Map.fetch!(:id)

                jury? = if row.pres == -1, do: true, else: false

                {:ok, slide} =
                  SM.Slides.update(slide, %{subject_id: subject_id, status: SM.Slides.jury_bool_to_status(jury?)})

                [v1] = SM.Evaluations.list_by_value(row.v1)
                [v2] = SM.Evaluations.list_by_value(row.v2)
                [v3] = SM.Evaluations.list_by_value(row.v3)

                {:ok, _slide_eval} = SM.Slides.evaluate(competition_id, slide.id, v1.id)
                {:ok, _slide_eval} = SM.Slides.evaluate(competition_id, slide.id, v2.id)
                {:ok, _slide_eval} = SM.Slides.evaluate(competition_id, slide.id, v3.id)

                penalty? = if row.pen == -1, do: true, else: false

                _result =
                  if penalty? do
                    {:ok, _slide} = SM.Slides.apply_penalty(slide.id)
                  end

                :ok = SM.Slides.generate_thumbnail(competition_id, user_id, file_name, :small)

                {:ok, slide} = SM.Slides.get(slide.id)
                slide

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :slide, Map.new(slide))
      accumulator = Map.put(accumulator, :slides, slides)
      {:ok, accumulator}
    end
  end

  defp migrate_slides(conn, accumulator, _version) do
    with {:ok, slide} <- get_table_data(conn, :slide, [:*], :id) do
      slides =
        Map.new(slide, fn {key, row} ->
          new_row =
            row
            |> get_or_create(nil, nil, [], @similarity_threshold)
            |> case do
              {:ok, :create} ->
                user_id = accumulator |> Map.fetch!(:users) |> Map.fetch!(row."ID_concorrente") |> Map.fetch!(:id)

                competition_id = accumulator |> Map.fetch!(:competition) |> Map.fetch!(:id)

                participant_dir =
                  accumulator |> Map.fetch!(:participants) |> Map.fetch!(row."ID_concorrente") |> String.trim(".")

                source_path = conn |> Map.fetch!(:directory) |> Path.join(participant_dir) |> Path.join(row.nomefile)

                file_name = Path.basename(source_path)
                %File.Stat{size: file_size} = File.stat!(source_path)

                {:ok, slide} =
                  SM.Slides.create_and_store_slide_file(
                    competition_id,
                    user_id,
                    file_name,
                    file_size,
                    "image/jpeg",
                    source_path
                  )

                subject_id = accumulator |> Map.fetch!(:subjects) |> Map.fetch!(row."ID_pesce") |> Map.fetch!(:id)

                jury? = if row.pres == -1, do: true, else: false

                {:ok, slide} =
                  SM.Slides.update(slide, %{subject_id: subject_id, status: SM.Slides.jury_bool_to_status(jury?)})

                [v1] = SM.Evaluations.list_by_value(row.v1)
                [v2] = SM.Evaluations.list_by_value(row.v2)
                [v3] = SM.Evaluations.list_by_value(row.v3)

                {:ok, _slide_eval} = SM.Slides.evaluate(competition_id, slide.id, v1.id)
                {:ok, _slide_eval} = SM.Slides.evaluate(competition_id, slide.id, v2.id)
                {:ok, _slide_eval} = SM.Slides.evaluate(competition_id, slide.id, v3.id)

                penalty? = if row.pen == -1, do: true, else: false

                _result =
                  if penalty? do
                    {:ok, _slide} = SM.Slides.apply_penalty(slide.id)
                  end

                :ok = SM.Slides.generate_thumbnail(competition_id, user_id, file_name, :small)

                {:ok, slide} = SM.Slides.get(slide.id)
                slide

              {:ok, existing} ->
                existing
            end

          {key, new_row}
        end)

      accumulator = Map.put(accumulator, :slide, Map.new(slide))
      accumulator = Map.put(accumulator, :slides, slides)
      {:ok, accumulator}
    end
  end

  defp connect_to_db(path) do
    case Basic.open(path) do
      {:ok, conn} ->
        Logger.debug("Opening DB at: #{conn.directory}")
        {:ok, conn}

      {:error, %Exqlite.Error{message: message, statement: nil}} ->
        Logger.error("Unable to open SQLite DB: #{message}\nPath: #{path}")
        {:error, :db_connection_failed}
    end
  end

  defp disconnect_from_db(conn) do
    Logger.debug("Closing DB at: #{conn.directory}")
    Basic.close(conn)
  end

  defp get_or_create(old_row, old_search_key, new_search_key, existing_rows, similarity_threshold) do
    fields_fun = to_fields_fun(old_search_key)
    search_value = fields_fun.(old_row)

    case calculate_similarities(search_value, existing_rows, new_search_key) do
      [{dist, best} | _rest] ->
        best_match_value = to_fields_fun(new_search_key).(best)
        round_perc_dist = Float.round(dist, 2) * 100

        cond do
          dist >= similarity_threshold ->
            {:ok, best}

          dist == 0.0 and best_match_value == nil and search_value == nil ->
            {:ok, :create}

          true ->
            Logger.debug(
              "Closest match '#{best_match_value}' (#{round_perc_dist}%) is less than #{similarity_threshold * 100}% similar to '#{search_value}'. Inserting a new record..."
            )

            {:ok, :create}
        end

      [] ->
        {:ok, :create}
    end
  end

  defp calculate_similarities(old_value, existing_rows, fields) do
    fields_fun = to_fields_fun(fields)

    existing_rows
    |> Enum.map(fn match ->
      case {old_value, fields_fun.(match)} do
        {nil, nil} -> {0.00, match}
        {_any, new_value} -> {String.jaro_distance(old_value, new_value), match}
      end
    end)
    |> Enum.sort_by(&elem(&1, 0), :desc)
  end

  defp to_fields_fun(nil) do
    fn _row ->
      nil
    end
  end

  defp to_fields_fun([_ | _] = fields) do
    fn row ->
      fields
      |> Enum.reduce("", fn
        field, acc when is_atom(field) ->
          Enum.join([acc, Map.fetch!(row, field)], " ")

        field_fun, acc when is_function(field_fun) ->
          Enum.join([acc, field_fun.(row)], " ")
      end)
      |> String.trim()
      |> String.downcase()
    end
  end

  defp to_fields_fun(field) when is_atom(field) do
    fn row ->
      row
      |> Map.fetch!(field)
      |> String.downcase()
    end
  end

  # defp get_records_count(conn, table_name) do
  #   conn
  #   |> Basic.exec("select count(*) from #{table_name}", [])
  #   |> Basic.rows()
  #   |> case do
  #     {:ok, [[count]], ["count(*)"]} ->
  #       {:ok, count}

  #     {:error, reason} = error ->
  #       Logger.error("Error counting record in table '#{table_name}': #{inspect(reason)}")
  #       error
  #   end
  # end

  defp get_table_data(conn, table_name, old_fields \\ [:*], pk \\ :ID) do
    keys_str = Enum.join(old_fields, ", ")

    with {:ok, rows, columns} <-
           conn
           |> Basic.exec("select #{keys_str} from #{table_name}", [])
           |> Basic.rows() do
      columns = Enum.map(columns, &String.to_atom/1)

      data =
        rows
        |> Stream.map(fn row ->
          columns
          |> Enum.zip(row)
          |> Map.new()
        end)
        |> Stream.map(&{Map.fetch!(&1, pk), &1})
        |> Stream.into(%{})

      {:ok, data}
    end
  end
end
