defmodule SM.Slides.SlideFlag do
  @moduledoc """
  SlideFlag schema
  """
  use SM, :schema

  alias SM.Slides.Slide

  @types Application.compile_env(:safarimanager, [__MODULE__, :types])

  @derive {Jason.Encoder,
           only: [
             :id,
             :slide_id,
             :type,
             :context,
             :comment,
             :resolved,
             :inserted_at,
             :updated_at
           ]}
  schema "slide_flags" do
    belongs_to :slide, Slide
    field :type, Ecto.Enum, values: Keyword.keys(@types)
    field :context, :map, default: %{}
    field :comment, :string
    field :resolved, :boolean

    timestamps()
  end

  @doc false
  @spec changeset(t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(slide_flag, attrs) do
    slide_flag
    |> cast(attrs, [:slide_id, :type, :context, :comment, :resolved])
    |> validate_required([:slide_id, :type])
    |> foreign_key_constraint(:slide_id)
    |> unique_constraint([:slide_id, :type])
  end

  @spec get_types :: [{:wrong_subject | :unrecognizable | :distinction | :note, String.t()}]
  def get_types do
    @types
  end
end
