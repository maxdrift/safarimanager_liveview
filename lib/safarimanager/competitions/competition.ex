defmodule SM.Competitions.Competition do
  @moduledoc """
  Competition schema
  """
  use SM, :schema

  schema "competitions" do
    field :name, :string
    field :start_time, :utc_datetime_usec
    field :end_time, :utc_datetime_usec
    field :street_name, :string
    field :street_number, :string
    field :postal_code, :string
    field :city, :string
    field :state, :string
    field :country, :string
    field :allowed_evaluations, {:array, Ecto.UUID}, default: []
    field :req_evaluations_count, :integer, default: 0
    field :req_jurors_count, :integer, default: 0

    timestamps()
  end

  @spec changeset(Competition.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def changeset(competition, attrs) do
    competition
    |> cast(attrs, [
      :name,
      :start_time,
      :end_time,
      :street_name,
      :street_number,
      :postal_code,
      :city,
      :state,
      :country,
      :allowed_evaluations,
      :req_evaluations_count,
      :req_jurors_count
    ])
    |> validate_required([
      :name
    ])
  end
end
