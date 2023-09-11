defmodule SM.Jurors.Juror do
  @moduledoc """
  Juror schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Competitions.Competition

  schema "jurors" do
    belongs_to :user, User
    belongs_to :competition, Competition

    timestamps()
  end

  @spec changeset(Juror.t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:user_id, :competition_id])
    |> validate_required([:user_id, :competition_id])
    |> unique_constraint([:user, :competition], name: :jurors_user_id_competition_id_index)
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required(__MODULE__.__schema__(:fields))
    |> unique_constraint(:id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> unique_constraint([:user, :competition], name: :jurors_user_id_competition_id_index)
  end
end
