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
         %DateTime{year: year} = start_time,
         %DateTime{year: year} = end_time
       ) do
    Calendar.strftime(start_time, "%d %b %Y → ") <> Calendar.strftime(end_time, "%d %b %Y")
  end
end
