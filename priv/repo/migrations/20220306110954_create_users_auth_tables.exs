defmodule SM.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    if SM.Repo.__adapter__() == Ecto.Adapters.SQLite3 do
      create table(:users, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :email, :string, null: false, collate: :nocase
        add :hashed_password, :string, null: false
        add :confirmed_at, :naive_datetime
        timestamps()
      end
    else
      execute "CREATE EXTENSION IF NOT EXISTS citext", ""

      create table(:users, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :email, :citext, null: false
        add :hashed_password, :string, null: false
        add :confirmed_at, :naive_datetime
        timestamps()
      end
    end

    create unique_index(:users, [:email])

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
