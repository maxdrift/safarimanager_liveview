defmodule SM.Repo.Migrations.MigrateOldFlagsToNewTable do
  use Ecto.Migration

  import Ecto.Query

  alias SM.Slides.SlideFlag
  alias SM.Repo

  defmodule Slide do
    @moduledoc false
    use SM, :schema

    alias SM.Slides.SlideFlag

    defmodule Flags do
      @moduledoc false
      use SM, :schema

      defmodule WrongSubjectContext do
        @moduledoc false
        use SM, :schema

        @primary_key false
        embedded_schema do
          field(:from, Ecto.UUID)
          field(:to, Ecto.UUID)
        end

        def changeset(flags, attrs) do
          cast(flags, attrs, [:from, :to])
        end
      end

      @primary_key false
      embedded_schema do
        field(:wrong_subject, :boolean, default: false)
        embeds_one(:wrong_subject_ctx, WrongSubjectContext, on_replace: :update)
        field(:other_reason, :boolean, default: false)
        field(:other_reason_ctx, :string)
      end

      @spec changeset(t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
      def changeset(flags, attrs) do
        flags
        |> cast(attrs, [
          :wrong_subject,
          :other_reason,
          :other_reason_ctx
        ])
        |> cast_embed(:wrong_subject_ctx)
      end
    end

    defmodule SlideFlag do
      @moduledoc false
      use SM, :schema

      alias __MODULE__.Slide

      schema "slide_flags" do
        belongs_to(:slide, Slide)
        field(:type, Ecto.Enum, values: [:wrong_subject, :unrecognizable, :distinction, :note])
        field(:context, :map, default: %{})
        field(:comment, :string)
        field(:resolved, :boolean)

        Ecto.Schema.timestamps()
      end

      @doc false
      def changeset(slide_flag, attrs) do
        slide_flag
        |> cast(attrs, [:slide_id, :type, :context, :comment, :resolved])
        |> validate_required([:slide_id, :type])
        |> foreign_key_constraint(:slide_id)
        |> unique_constraint([:slide_id, :type])
      end
    end

    schema "slides" do
      embeds_one(:flags, Flags, on_replace: :update)
      has_many(:slide_flags, SlideFlag)
    end

    @doc false
    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [])
      |> cast_embed(:flags)
    end
  end

  def up do
    slides = Repo.all(from(s in Slide, where: not is_nil(s.flags)))

    Enum.each(slides, fn slide ->
      if slide.flags.wrong_subject do
        {:ok, _slide_flag} =
          %SlideFlag{}
          |> SlideFlag.changeset(%{
            slide_id: slide.id,
            type: :wrong_subject,
            context: %{
              "from" => slide.flags.wrong_subject_ctx.from,
              "to" => slide.flags.wrong_subject_ctx.to
            }
          })
          |> Repo.insert()
      end

      if slide.flags.other_reason do
        {type, context} =
          case slide.flags.other_reason_ctx do
            "unrecognizable" -> {:unrecognizable, nil}
            "distinction" -> {:distinction, nil}
            other -> {:note, %{"message" => other}}
          end

        {:ok, _slide_flag} =
          %SlideFlag{}
          |> SlideFlag.changeset(%{
            slide_id: slide.id,
            type: type,
            context: context
          })
          |> Repo.insert()
      end

      {:ok, _slide} =
        slide
        |> Ecto.Changeset.change(flags: nil)
        |> Repo.update()
    end)
  end

  def down do
    slide_flags =
      SlideFlag
      |> Repo.all()
      |> Enum.group_by(& &1.slide_id)

    Enum.each(slide_flags, fn {slide_id, flags} ->
      old_flags = %{
        wrong_subject: false,
        wrong_subject_ctx: nil,
        other_reason: false,
        other_reason_ctx: nil
      }

      old_flags =
        Enum.reduce(flags, old_flags, fn flag, acc ->
          case flag.type do
            :wrong_subject ->
              acc
              |> Map.put(:wrong_subject, true)
              |> Map.put(:wrong_subject_ctx, flag.context)

            :note ->
              acc
              |> Map.put(:other_reason, true)
              |> Map.put(:other_reason_ctx, flag.context["message"])

            other_type ->
              acc
              |> Map.put(:other_reason, true)
              |> Map.put(:other_reason_ctx, Atom.to_string(other_type))
          end
        end)

      {:ok, _slide} =
        Slide
        |> Repo.get(slide_id)
        |> Slide.changeset(%{flags: old_flags})
        |> Repo.update()

      flags_count = Enum.count(flags)
      {^flags_count, nil} = Repo.delete_all(from(SlideFlag, where: [slide_id: ^slide_id]))
    end)
  end
end
