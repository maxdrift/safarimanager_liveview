defmodule SMWeb.Components.CompetitionHeader do
  @moduledoc """
  Competition Header component.
  """
  use SMWeb, :component

  attr :competition, SM.Competitions.Competition, required: true

  def competition_header(assigns) do
    ~H"""
    <div class="pt-5 text-center">
      <div class="text-2xl">{@competition.name}</div>
      <div class="text-lg">
        {@competition.city || gettext("Somewhere...")} - {pretty_dates(
          @competition.start_time,
          @competition.end_time
        )}
      </div>
    </div>
    """
  end

  defp pretty_dates(%DateTime{day: day, month: month, year: year} = start_time, %DateTime{
         day: day,
         month: month,
         year: year
       }) do
    Calendar.strftime(start_time, "%d %b %Y")
  end

  defp pretty_dates(%DateTime{month: month, year: year} = start_time, %DateTime{month: month, year: year} = end_time) do
    Calendar.strftime(start_time, "%d → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  defp pretty_dates(%DateTime{year: year} = start_time, %DateTime{year: year} = end_time) do
    Calendar.strftime(start_time, "%d %b → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  defp pretty_dates(%DateTime{year: _year1} = start_time, %DateTime{year: _year2} = end_time) do
    Calendar.strftime(start_time, "%d %b %Y → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  defp pretty_dates(%DateTime{} = start_time, nil) do
    Calendar.strftime(start_time, "%d %b %Y")
  end

  defp pretty_dates(nil, _nil) do
    gettext("Sometime...")
  end
end
