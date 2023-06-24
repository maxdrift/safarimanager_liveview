defmodule SMWeb.Components.DateTimeString do
  @moduledoc """
  Datetime representation static component
  """

  use SMWeb, :surface_component

  prop value, :struct, required: true

  def render(assigns) do
    ~F"""
    {format_date(@value)}
    """
  end

  defp format_date(nil) do
    gettext("N/A")
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
