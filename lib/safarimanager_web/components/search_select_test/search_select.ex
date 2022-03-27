defmodule SMWeb.Components.SearchSelect do
  @moduledoc """
  Search select component.
  """
  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [input_id: 2]

  prop items, :list, default: []
  prop search, :event, required: true
  prop select_item, :event, required: true
  prop selected_label, :string, default: nil
  prop phx_debounce, :integer, default: 500
end
