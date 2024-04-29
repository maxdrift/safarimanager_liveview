defmodule SM.Competitions.CompetitionSettings do
  @moduledoc """
  Competition settings schema
  """
  use SM, :schema

  alias SM.Competitions.Competition

  @coefficient_modes Application.compile_env!(:safarimanager, [__MODULE__, :coefficient_modes])
  @dynamic_coefficient_modes Application.compile_env!(:safarimanager, [__MODULE__, :dynamic_coefficient_modes])

  defmodule DynamicCoefficient do
    @moduledoc """
    Dynamic coefficient model
    """
    use SM, :schema

    @derive {Jason.Encoder,
             only: [
               :name,
               :from,
               :to,
               :value
             ]}
    @primary_key false
    embedded_schema do
      field :name, :string, primary_key: true
      field :from, :decimal
      field :to, :decimal
      field :value, :decimal
    end

    def changeset(dynamic_coeff \\ %DynamicCoefficient{}, attrs) do
      dynamic_coeff
      |> cast(attrs, [:name, :from, :to, :value])
      |> validate_required([:name, :from, :to, :value])
    end
  end

  @derive {Jason.Encoder,
           only: [
             :evaluations_per_juror,
             :number_of_jurors,
             :max_jury_slides,
             :max_submitted_slides,
             :proportional_submission,
             :submission_ratio,
             :fixed_points_multiplier,
             :penalty_amount,
             :coefficient_mode,
             :dynamic_coefficient_mode,
             :dynamic_coefficients,
             :competition_id,
             :inserted_at,
             :updated_at
           ]}
  @primary_key false
  schema "competition_settings" do
    field :evaluations_per_juror, :integer
    field :number_of_jurors, :integer
    field :max_jury_slides, :integer
    field :max_submitted_slides, :integer
    field :proportional_submission, :boolean, default: true
    field :submission_ratio, :decimal
    field :fixed_points_multiplier, :decimal
    field :penalty_amount, :decimal
    field :coefficient_mode, Ecto.Enum, values: Keyword.keys(@coefficient_modes), default: :all
    field :dynamic_coefficient_mode, Ecto.Enum, values: Keyword.keys(@coefficient_modes), default: :disabled

    embeds_many :dynamic_coefficients, DynamicCoefficient, on_replace: :delete

    belongs_to :competition, Competition, primary_key: true

    timestamps()
  end

  @spec changeset(CompetitionSettings.t(), %{(String.t() | atom()) => any()}) ::
          Ecto.Changeset.t()
  def changeset(competition_settings, attrs) do
    competition_settings
    |> cast(attrs, [
      :evaluations_per_juror,
      :number_of_jurors,
      :max_jury_slides,
      :max_submitted_slides,
      :proportional_submission,
      :submission_ratio,
      :fixed_points_multiplier,
      :penalty_amount,
      :coefficient_mode,
      :dynamic_coefficient_mode
    ])
    |> validate_required([
      :evaluations_per_juror,
      :number_of_jurors,
      :max_jury_slides,
      :max_submitted_slides,
      :submission_ratio,
      :fixed_points_multiplier,
      :penalty_amount
    ])
    |> cast_embed(:dynamic_coefficients)
  end

  @spec get_coefficient_modes :: [{atom(), String.t()}]
  def get_coefficient_modes do
    @coefficient_modes
  end

  @spec get_dynamic_coefficient_modes :: [{atom(), String.t()}]
  def get_dynamic_coefficient_modes do
    @dynamic_coefficient_modes
  end
end
