defmodule SMWeb.Components.Thumbnail do
  @moduledoc """
  A single gallery image.
  """
  use SMWeb, :component

  attr :click, :string
  attr :url, :string, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true

  def thumbnail(assigns) do
    ~H"""
    <div
      id={@url}
      class="photo-grid-div"
      style={"width:#{@width * 200 / @height}px;grow:#{@width * 200 / @height}"}
    >
      <.link
        navigate="/jury_viewer"
        class="photo-grid-i"
        style={"padding-bottom:#{@height / @width * 100}%"}
      >
        <img class="photo-grid-img" src={@url} alt="" />
      </.link>
    </div>
    """
  end
end
