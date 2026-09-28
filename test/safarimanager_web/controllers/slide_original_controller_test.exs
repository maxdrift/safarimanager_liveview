defmodule SMWeb.SlideOriginalControllerTest do
  use SMWeb.ConnCase

  import SM.CompetitionsFixtures

  alias SM.Slides
  alias SM.Slides.Storage

  setup [
    :register_and_log_in_user,
    :create_organization,
    :create_evaluation,
    :create_competition,
    :create_category,
    :register_users,
    :enroll_participants,
    :internal_slide
  ]

  defp internal_slide(context) do
    competition = context.competition
    slide_user = hd(context.users)

    uploads_dir =
      competition.id
      |> Slides.get_uploads_path(slide_user.id)
      |> tap(&File.mkdir_p!/1)

    file_name = "sample.jpg"
    file_path = Path.join(uploads_dir, file_name)
    File.cp!(Path.expand("../../fixtures/exif_sample.jpg", __DIR__), file_path)

    {:ok, slide} =
      Slides.create_slide_from_file(
        competition.id,
        slide_user.id,
        file_name,
        File.stat!(file_path).size,
        "image/jpeg",
        file_path,
        :internal
      )

    :ok = Slides.generate_thumbnail_from_source(slide, :small)

    Map.merge(context, %{slide: slide, file_path: file_path})
  end

  test "serves original when reachable", %{conn: conn, slide: slide} do
    conn = get(conn, ~p"/slides/#{slide.id}/original")
    assert conn.status == 200
    assert byte_size(conn.resp_body) > 0
  end

  test "falls back when original missing but thumbnail exists", %{conn: conn, slide: slide, file_path: file_path} do
    File.rm!(file_path)
    refute Storage.original_reachable?(slide)
    assert File.exists?(Storage.thumbnail_path(slide, :small))

    conn = get(conn, ~p"/slides/#{slide.id}/original")
    assert conn.status == 200
  end

  test "404 for unknown slide", %{conn: conn} do
    conn = get(conn, ~p"/slides/#{Ecto.UUID.generate()}/original")
    assert conn.status == 404
  end
end
