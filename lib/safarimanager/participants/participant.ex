defmodule SM.Participants.Participant do
  @moduledoc """
  Participant schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Categories.Category
  alias SM.Competitions.Competition

  @primary_key false
  schema "participants" do
    belongs_to :user, User, primary_key: true
    belongs_to :competition, Competition, primary_key: true
    belongs_to :category, Category
    field :number, :integer

    timestamps()
  end

  @spec changeset(Participant.t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:user_id, :competition_id, :category_id, :number])
    |> validate_required([:user_id, :competition_id, :category_id, :number])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint(:number, name: :participants_competition_id_number_index)
  end
end
