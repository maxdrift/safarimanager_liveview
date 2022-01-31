defmodule SMWeb.Components.Subjects.List do
  @moduledoc """
  Subjects list component
  """
  use Surface.Component

  alias Surface.Components.LivePatch

  prop items, :list, required: true
  prop all_selected?, :boolean, required: true
  prop any_selected?, :boolean, required: true
  prop select_one, :event, required: true
  prop select_all, :event, required: true
  prop delete_one, :event, required: true

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
