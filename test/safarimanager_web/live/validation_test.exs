defmodule SMWeb.Live.ValidationTest do
  use SMWeb.ConnCase
  use Gettext, backend: SMWeb.Gettext

  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.Slides
  alias SM.Subjects

  describe "Slides validation" do
    setup [
      :register_and_log_in_user,
      :create_organization,
      :create_competition,
      :create_category,
      :register_users,
      :enroll_participants,
      :enroll_jurors,
      :create_slides,
      :select_slides,
      :add_slide_flags
    ]

    test "can render the page", %{conn: conn, competition: competition} do
      {:ok, lv, _html} = live(conn, ~p"/organize/#{competition.id}/validation_launcher")

      assert lv
             |> element("#start-validation-btn")
             |> has_element?()
    end

    test "shows flags in table", %{conn: conn, competition: competition, slide_flags: flags} do
      {:ok, _lv, html} = live(conn, ~p"/organize/#{competition.id}/validation_launcher")

      html = Floki.parse_document!(html)

      subjects = Subjects.list()

      for flag <- flags do
        {:ok, slide} = Slides.get(flag.slide_id)
        [row] = Floki.find(html, "#validation-detail-row-#{flag.slide_id}")

        assert [{"span", _attrib, [file_name]}] = Floki.find(row, ".sm-file-name")

        assert [{"span", _attrib, [subject_name]}] = Floki.find(row, ".sm-subject-name")

        assert [{"div", _attrib, [status]}] = Floki.find(row, ".sm-status")

        assert file_name =~ slide.file_name
        assert subject_name =~ slide.subject.name
        assert status =~ status_to_label(slide.status)

        case flag.type do
          :wrong_subject ->
            assert [{"span", _attrib, [correction]}] = Floki.find(row, ".sm-wrong-subject")

            assert correction =~
                     "#{subject_name(subjects, slide.subject_id)} → #{subject_name(subjects, flag.context["to"])}"

          :unrecognizable ->
            assert [{"span", _attrib, [tick]}] = Floki.find(row, ".sm-unrecognizable")
            assert tick =~ "✓"

          :distinction ->
            assert [{"span", _attrib, [tick]}] = Floki.find(row, ".sm-distinction")
            assert tick =~ "✓"

          :note ->
            assert [{"div", _attrib, [note]}] = Floki.find(row, ".sm-note")
            assert note =~ flag.context["message"]
        end
      end
    end
  end

  defp subject_name(subjects, subject_id) do
    Enum.find_value(subjects, "N/A", fn s ->
      if s.id == subject_id, do: s.name
    end)
  end

  defp status_to_label(:submitted_fixed), do: gettext("Fixed points")
  defp status_to_label(:submitted_jury), do: gettext("Jury")
end
