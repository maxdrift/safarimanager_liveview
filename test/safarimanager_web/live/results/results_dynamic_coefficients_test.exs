defmodule SMWeb.Live.Results.ResultsDynamicCoefficientsTest do
  @moduledoc """
  Integration coverage for the Results LiveView when only dynamic coefficients apply
  to fixed-point slides (static subject coefficients disabled).
  """

  use SMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias SM.AccountsFixtures
  alias SM.Categories
  alias SM.Competitions
  alias SM.Evaluations
  alias SM.Organizations
  alias SM.Participants
  alias SM.Results
  alias SM.Slides
  alias SM.Subjects

  test "Results page shows per-slide coefficients from dynamic intervals for submitted_fixed slides", %{
    conn: conn
  } do
    {:ok, organization} = Organizations.create(%{"name" => "Dyn Coef Org", "location" => "Test"})

    {:ok, evaluation} =
      Evaluations.create(%{
        "value" => 5,
        "name" => "Five"
      })

    {:ok, competition} =
      Competitions.create(%{
        "name" => "Dynamic fixed-points cup",
        "type" => :qualification,
        "organization_id" => organization.id,
        "competitions_evaluations" => [%{"evaluation_id" => evaluation.id}]
      })

    {:ok, competition} = Competitions.get(competition.id)

    assert {:ok, _} =
             Competitions.update(competition, %{
               "settings" => settings_attrs_dynamic_fixed_only(competition.settings)
             })

    {:ok, category} = Categories.create(%{"name" => "Reflex", "camera_type" => :reflex})

    users =
      for _ <- 1..4 do
        AccountsFixtures.competition_user_fixture(%{
          organization_id: organization.id,
          category_id: category.id
        })
      end

    for {user, n} <- Enum.with_index(users, 1) do
      assert {:ok, _} =
               Participants.create(%{
                 user_id: user.id,
                 competition_id: competition.id,
                 category_id: category.id,
                 number: n
               })
    end

    base_id = System.unique_integer([:positive])

    assert {:ok, subject_common} =
             Subjects.create(%{
               "name" => "Common fish #{base_id}",
               "numeric_id" => base_id,
               "type" => :fish,
               "coefficient" => 1,
               "scientific_name" => "Communis testus"
             })

    assert {:ok, subject_medium} =
             Subjects.create(%{
               "name" => "Medium fish #{base_id}",
               "numeric_id" => base_id + 1,
               "type" => :fish,
               "coefficient" => 1,
               "scientific_name" => "Medius testus"
             })

    assert {:ok, subject_rare} =
             Subjects.create(%{
               "name" => "Rare fish #{base_id}",
               "numeric_id" => base_id + 2,
               "type" => :fish,
               "coefficient" => 1,
               "scientific_name" => "Rarus testus"
             })

    [u1, u2, u3, u4] = users

    slides_spec = [
      {u1, "p1-common.jpg", subject_common.id},
      {u1, "p1-exclusive.jpg", subject_rare.id},
      {u2, "p2-common.jpg", subject_common.id},
      {u2, "p2-medium.jpg", subject_medium.id},
      {u3, "p3-common.jpg", subject_common.id},
      {u3, "p3-medium.jpg", subject_medium.id},
      {u4, "p4-common.jpg", subject_common.id}
    ]

    slide_rows =
      for {user, file_name, subject_id} <- slides_spec do
        assert {:ok, slide} =
                 Slides.create(%{
                   user_id: user.id,
                   competition_id: competition.id,
                   file_name: file_name,
                   file_size: 1000
                 })

        assert {:ok, slide} =
                 Slides.update(slide, %{subject_id: subject_id, status: :submitted_fixed})

        {user.id, file_name, slide.id}
      end

    {:ok, results} = Results.list(competition.id)

    by_user_id = Map.new(results, &{&1.user.id, &1})

    coeff_by_file = fn user_id ->
      by_user_id
      |> Map.fetch!(user_id)
      |> Map.fetch!(:slides)
      |> Map.new(fn row -> {row.slide.file_name, row.coefficient} end)
    end

    c1 = coeff_by_file.(u1.id)
    assert_decimal_eq(c1["p1-exclusive.jpg"], "4")
    assert_decimal_eq(c1["p1-common.jpg"], "2")

    c2 = coeff_by_file.(u2.id)
    assert_decimal_eq(c2["p2-medium.jpg"], "3")
    assert_decimal_eq(c2["p2-common.jpg"], "2")

    c3 = coeff_by_file.(u3.id)
    assert_decimal_eq(c3["p3-medium.jpg"], "3")
    assert_decimal_eq(c3["p3-common.jpg"], "2")

    c4 = coeff_by_file.(u4.id)
    assert_decimal_eq(c4["p4-common.jpg"], "2")

    conn = log_in_user(conn, hd(users))

    {:ok, view, _html} = live(conn, ~p"/organize/#{competition.id}/results")

    assert has_element?(view, "#results-content")

    for {user_id, file_name, slide_id} <- slide_rows do
      expected =
        user_id
        |> coeff_by_file.()
        |> Map.fetch!(file_name)
        |> Decimal.to_string(:normal)

      coeff_html =
        view
        |> element("#results-slide-#{slide_id} [data-test-results-slide-coefficient]")
        |> render()

      assert coeff_html =~ expected,
             "expected coefficient #{expected} for #{file_name}, rendered: #{coeff_html}"
    end
  end

  defp settings_attrs_dynamic_fixed_only(settings) do
    %{
      "evaluations_per_juror" => settings.evaluations_per_juror,
      "number_of_jurors" => settings.number_of_jurors,
      "max_jury_slides" => settings.max_jury_slides,
      "max_submitted_slides" => settings.max_submitted_slides,
      "proportional_submission" => settings.proportional_submission,
      "submission_ratio" => decimal_to_string(settings.submission_ratio),
      "fixed_points_multiplier" => decimal_to_string(settings.fixed_points_multiplier),
      "submission_bonus_per_slide" => decimal_to_string(settings.submission_bonus_per_slide),
      "penalty_amount" => decimal_to_string(settings.penalty_amount),
      "coefficient_mode" => "disabled",
      "dynamic_coefficient_mode" => "submitted_fixed",
      "dynamic_coefficients" => [
        %{"name" => "tier_common", "from" => "0.66", "to" => "1.0", "value" => "1"},
        %{"name" => "tier_mid", "from" => "0.33", "to" => "0.66", "value" => "2"},
        %{"name" => "tier_rare", "from" => "0", "to" => "0.33", "value" => "3"}
      ]
    }
  end

  defp decimal_to_string(nil), do: "0"

  defp decimal_to_string(%Decimal{} = d), do: Decimal.to_string(d)

  defp decimal_to_string(n) when is_integer(n), do: Integer.to_string(n)

  defp assert_decimal_eq(%Decimal{} = got, expected) do
    assert Decimal.eq?(got, Decimal.new(expected))
  end
end
