defmodule SMWeb.Live.NewCompetitionTest do
  use SMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SM.CompetitionsFixtures

  alias SM.Competitions

  describe "list competitions" do
    setup [:register_and_log_in_user, :create_three_competitions]

    test "shows competitions in descending order of creation", %{conn: conn, competitions: competitions} do
      {:ok, lv, _html} = live(conn, ~p"/organize/new")

      assert lv
             |> element("#competitions-grid > :first-child")
             |> render() =~ "new-competition-button"

      competitions
      |> Enum.sort_by(& &1.inserted_at, :desc)
      |> Enum.with_index()
      |> Enum.each(fn {competition, index} ->
        assert lv
               |> element("#competitions-grid > :nth-child(#{index + 2})")
               |> render() =~ "#{competition.id}-competition-tile"
      end)
    end
  end

  describe "create a new competition" do
    setup [:register_and_log_in_user, :create_organization, :create_evaluation]

    test "creates a new Competition with default settings", %{
      conn: conn,
      organization: organization,
      evaluation: evaluation
    } do
      {:ok, lv, _html} = live(conn, ~p"/organize/new")

      assert {:error,
              {:live_redirect,
               %{
                 kind: :push,
                 to: new_path
               }}} =
               lv
               |> form("#new-competition-form",
                 entity: %{
                   "name" => "Test Competition",
                   "organization_id" => organization.id,
                   "type" => :qualification,
                   "competitions_evaluations" => %{
                     "0" => %{
                       "evaluation_id" => evaluation.id
                     }
                   }
                 }
               )
               |> render_submit()

      assert ["organize", competition_id, "participants"] =
               String.split(new_path, "/", trim: true)

      assert {:ok, competition} = Competitions.get(competition_id)

      assert competition.name == "Test Competition"
      assert competition.organization_id == organization.id
      assert competition.type == :qualification
      assert [assigned_evaluation] = competition.allowed_evaluations
      assert assigned_evaluation.id == evaluation.id
    end

    test "fails validation if Organization is missing", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/organize/new")

      html =
        render_change(
          lv,
          "validate",
          entity: %{
            "name" => "Test Competition"
          }
        )

      assert [{"span", _attrs, ["can't be blank"]}] =
               html
               |> Floki.parse_document!()
               |> Floki.find(~s([phx-feedback-for="entity[organization_id]"]))
    end
  end
end
