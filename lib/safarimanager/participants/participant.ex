defmodule SM.Participants.Participant do
  @moduledoc """
  Participant schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Competitions.Competition

  @primary_key false
  schema "participants" do
    belongs_to :user, User, primary_key: true
    belongs_to :competition, Competition, primary_key: true

    timestamps()
  end

  @spec changeset(Participant.t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:user_id, :competition_id])
    |> validate_required([:user_id, :competition_id])
    |> unique_constraint(:user_id, name: :participants_user_id_competition_id_index)
  end
end
