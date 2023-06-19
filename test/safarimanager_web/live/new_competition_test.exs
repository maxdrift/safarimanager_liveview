defmodule SMWeb.Live.NewCompetitionTest do
  use SMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SM.Competitions
  alias SM.Organizations

  defp create_organization(_context) do
    {:ok, organization} =
      Organizations.create(%{"name" => "G.R.O. Sub Catania", "location" => "Catania"})

    %{organization: organization}
  end

  describe "Create a new competition" do
    setup [:register_and_log_in_user, :create_organization]

    test "creates a new Competition with default settings", %{
      conn: conn,
      organization: organization
    } do
      {:ok, lv, _html} = live(conn, ~p"/organize/new")

      assert {:error,
              {:live_redirect,
               %{
                 kind: :push,
                 to: new_path
               }}} =
               lv
               |> form("form",
                 entity: %{
                   "name" => "Test Competition",
                   "organization_id" => organization.id
                 }
               )
               |> render_submit()

      assert ["organize", competition_id, "participants"] =
               String.split(new_path, "/", trim: true)

      assert {:ok, _competition} = Competitions.get(competition_id)
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
