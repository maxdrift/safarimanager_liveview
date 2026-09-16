defmodule SMWeb.Live.Admin.Competitions.EraseDiscardedSlidesTest do
  @moduledoc false
  use SMWeb.ConnCase

  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.AccountsFixtures
  alias SM.Participants
  alias SM.Slides
  alias SM.Subjects

  describe "erase-discarded-slides" do
    setup [:register_and_log_in_user, :create_organization, :create_category]

    setup %{organization: organization, category: category} do
      %{competition: competition} = create_competition(%{organization: organization})

      n = System.unique_integer([:positive])

      {:ok, subject} =
        Subjects.create(%{
          "name" => "Erase test subject #{n}",
          "numeric_id" => n,
          "type" => :fish,
          "coefficient" => 3,
          "scientific_name" => "Testus erase."
        })

      user =
        AccountsFixtures.competition_user_fixture(%{
          organization_id: organization.id,
          category_id: category.id
        })

      {:ok, _participant} =
        Participants.create(%{
          user_id: user.id,
          competition_id: competition.id,
          category_id: category.id,
          number: 1
        })

      {:ok, discarded1} =
        Slides.create(%{
          user_id: user.id,
          competition_id: competition.id,
          file_name: "discarded-1.JPG",
          file_size: 1111,
          status: :discarded
        })

      {:ok, discarded2} =
        Slides.create(%{
          user_id: user.id,
          competition_id: competition.id,
          file_name: "discarded-2.JPG",
          file_size: 2222,
          status: :discarded
        })

      {:ok, kept} =
        Slides.create(%{
          user_id: user.id,
          competition_id: competition.id,
          file_name: "kept-jury.JPG",
          file_size: 3333,
          status: :submitted_jury,
          subject_id: subject.id
        })

      %{
        competition: competition,
        discarded_ids: [discarded1.id, discarded2.id],
        kept_id: kept.id
      }
    end

    test "context delete_many removes only discarded slides", %{
      competition: competition,
      discarded_ids: discarded_ids,
      kept_id: kept_id
    } do
      discarded = Slides.list_by_status(competition.id, :discarded)
      assert length(discarded) == 2

      assert {:ok, 2} =
               discarded
               |> Enum.map(& &1.id)
               |> Slides.delete_many()

      assert Slides.list_by_status(competition.id, :discarded) == []
      assert Enum.all?(discarded_ids, fn id -> match?({:error, :not_found}, Slides.get(id)) end)
      assert {:ok, kept} = Slides.get(kept_id)
      assert kept.status == :submitted_jury
      assert Slides.get_slides_size_by_status(competition.id, :discarded) == nil
    end

    test "LiveView erase-discarded-slides confirms and deletes", %{
      conn: conn,
      competition: competition,
      discarded_ids: discarded_ids,
      kept_id: kept_id
    } do
      {:ok, view, html} = live(conn, ~p"/admin/competitions/#{competition.id}")

      assert html =~ "Erase"
      refute html =~ ~r/phx-click="erase-discarded-slides"[^>]*btn-disabled/

      view
      |> element("button[phx-click='erase-discarded-slides']")
      |> render_click()

      assert has_element?(view, "[data-el-confirm-form]")
      html = render(view)
      assert html =~ "Are you sure you want to delete all discarded slides?"
      # Confirm must stack above DaisyUI admin modals (z-index 999)
      assert html =~ "z-[1100]"

      view
      |> form("[data-el-confirm-form]")
      |> render_submit()

      html = render(view)
      assert html =~ "Deleted all discarded slides"

      assert Slides.list_by_status(competition.id, :discarded) == []
      assert Enum.all?(discarded_ids, fn id -> match?({:error, :not_found}, Slides.get(id)) end)
      assert {:ok, kept} = Slides.get(kept_id)
      assert kept.status == :submitted_jury
      assert Slides.get_slides_size_by_status(competition.id, :discarded) == nil
    end

    test "also deletes files on disk for discarded slides", %{competition: competition} do
      discarded = Slides.list_by_status(competition.id, :discarded)
      [slide | _] = discarded

      uploads_path = Slides.get_uploads_path(slide.competition_id, slide.user_id)
      File.mkdir_p!(uploads_path)
      file_path = Path.join(uploads_path, slide.file_name)
      File.write!(file_path, "fake-image-bytes")
      assert File.exists?(file_path)

      assert {:ok, _} = discarded |> Enum.map(& &1.id) |> Slides.delete_many()
      refute File.exists?(file_path)
    end
  end
end
