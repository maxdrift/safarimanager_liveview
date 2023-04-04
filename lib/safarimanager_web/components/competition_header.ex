defmodule SMWeb.Components.CompetitionHeader do
  @moduledoc """
  Competition Header component.
  """
  use SMWeb, :surface_component

  prop competition, :struct, required: true

  defp pretty_dates(
         %DateTime{day: day, month: month, year: year} = start_time,
         %DateTime{day: day, month: month, year: year}
       ) do
    Calendar.strftime(start_time, "%d %b %Y")
  end

  defp pretty_dates(
         %DateTime{month: month, year: year} = start_time,
         %DateTime{month: month, year: year} = end_time
       ) do
    Calendar.strftime(start_time, "%d → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  defp pretty_dates(
         %DateTime{year: year} = start_time,
         %DateTime{year: year} = end_time
       ) do
    Calendar.strftime(start_time, "%d %b → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  defp pretty_dates(
         %DateTime{year: _year1} = start_time,
         %DateTime{year: _year2} = end_time
       ) do
    Calendar.strftime(start_time, "%d %b %Y → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end

  defp pretty_dates(
         %DateTime{} = start_time,
         nil
       ) do
    Calendar.strftime(start_time, "%d %b %Y")
  end

  defp pretty_dates(nil, _nil) do
    "Sometime..."
  end
end
