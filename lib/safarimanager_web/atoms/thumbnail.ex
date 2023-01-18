defmodule SMWeb.Molecules.Thumbnail do
  @moduledoc """
  A single gallery image.
  """
  use SMWeb, :surface_component

  alias Surface.Components.LiveRedirect

  prop click, :event
  prop url, :string, required: true
  prop width, :integer, required: true
  prop height, :integer, required: true

  def render(assigns) do
    ~F"""
    <div
      id={@url}
      class="photo-grid-div"
      style={"width:#{@width * 200 / @height}px;grow:#{@width * 200 / @height}"}
    >
      <LiveRedirect
        to="/jury_viewer"
        class="photo-grid-i"
        opts={[style: "padding-bottom:#{@height / @width * 100}%"]}
      >
        <img class="photo-grid-img" src={@url} alt="">
      </LiveRedirect>
    </div>
    """
  end
end
