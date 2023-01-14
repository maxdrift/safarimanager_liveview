defmodule SM.Slides.SlideEvaluation do
  @moduledoc """
  SlideEvaluation schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Evaluations.Evaluation
  alias SM.Slides.Slide

  @derive {Jason.Encoder, only: [:user_id, :evaluation_id]}
  @primary_key false
  schema "slides_evaluations" do
    belongs_to :slide, Slide, primary_key: true
    belongs_to :user, User, primary_key: true
    belongs_to :evaluation, Evaluation

    timestamps()
  end

  @doc false
  @spec changeset(t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(slide_evaluation, attrs) do
    slide_evaluation
    |> cast(attrs, [:slide_id, :user_id, :evaluation_id])
    |> validate_required([:slide_id, :user_id, :evaluation_id])
    |> foreign_key_constraint(:slide_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:evaluation_id)
    |> unique_constraint([:slide, :user], name: :slides_evaluations_pkey)
    |> unique_constraint([:slide, :user], name: :slides_evaluations_slide_user_index)
  end
end
