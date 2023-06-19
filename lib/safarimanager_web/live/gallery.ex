defmodule SMWeb.Live.Gallery do
  @moduledoc """
  Live view handling display of a Slide gallery
  """
  use SMWeb, :surface_view

  alias SMWeb.Atoms.Thumbnail

  @lorempicsum_url "https://picsum.photos"

  @impl Phoenix.LiveView
  def handle_event("open-image", _value, socket) do
    {:noreply, socket}
  end

  defp generate_random_images(amount) do
    Enum.map(1..amount, fn index ->
      width = Enum.random(200..1000)
      height = Enum.random(200..1000)

      url =
        @lorempicsum_url
        |> URI.parse()
        |> URI.merge("/seed/#{index}/#{width}/#{height}")
        |> URI.to_string()

      {url, width, height}
    end)
  end
end
