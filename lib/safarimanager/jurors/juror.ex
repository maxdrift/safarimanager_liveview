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
  def changeset(juror, attrs) do
    juror
    |> cast(attrs, [:user_id, :competition_id])
    |> validate_required([:user_id, :competition_id])
    |> unique_constraint(:user_id, name: :jurors_user_id_competition_id_index)
  end
end
