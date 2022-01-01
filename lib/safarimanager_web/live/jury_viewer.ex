defmodule SMWeb.JuryViewer do
  @moduledoc """
  Live view to handle Jury operations i.e. evaluation of Slides
  """
  use Surface.LiveView

  alias SMWeb.Atoms.JuryToolbarButton

  @votes %{
    votes: [-100, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    prizes: ["distinguish"]
  }

  @images [
    "/images/slides/IMG_7380.JPG",
    "/images/slides/IMG_7381.JPG",
    "/images/slides/IMG_7385.JPG"
  ]

  def mount(_params, _session, socket) do
    # next_image = Enum.at(@images, 0)

    # image_name = String.split(next_image, "/") |> Enum.reverse() |> hd()
    # image_url = "/images/slides/#{image_name}"

    socket =
      socket
      |> assign(:images, @images)
      |> assign(:curr_index, 0)
      |> assign(:image_count, Enum.count(@images))
      |> assign(:votes, @votes.votes)
      |> assign(:prizes, @votes.prizes)
      |> assign(:given_votes, [])

    {:ok, socket}
  end

  def handle_params(%{"img" => image_name}, _url, socket) do
    socket =
      socket
      # Note: remember events pushed from the server via push_event are global
      # and will be dispatched to all active hooks on the client who are handling that event.
      |> push_event("new-image", %{options: %{image_url: "/images/slides/#{image_name}"}})

    {:noreply, socket}
  end

  def handle_params(%{}, _url, socket) do
    next_image = Enum.at(socket.assigns.images, socket.assigns.curr_index)

    image_name = String.split(next_image, "/") |> Enum.reverse() |> hd()
    # image_url = "/images/slides/#{image_name}"

    socket =
      socket
      # |> assign(:image_url, image_url)
      |> push_patch(to: "/jury_viewer?img=#{image_name}")
      # Note: remember events pushed from the server via push_event are global
      # and will be dispatched to all active hooks on the client who are handling that event.
      |> push_event("new-image", %{options: %{image_url: "/images/slides/#{image_name}"}})

    {:noreply, socket}
  end

  def handle_event("next-image", _data, socket) do
    next_index = rem(socket.assigns.curr_index + 1, socket.assigns.image_count)

    next_image = Enum.at(socket.assigns.images, next_index)

    image_name = String.split(next_image, "/") |> Enum.reverse() |> hd()
    # image_url = "/images/slides/#{image_name}"

    socket =
      socket
      |> assign(:curr_index, next_index)
      # |> assign(:image_url, image_url)
      |> push_patch(to: "/jury_viewer?img=#{image_name}")

    {:noreply, socket}
  end

  def handle_event("prev-image", _data, socket) do
    next_index = rem(socket.assigns.curr_index - 1, socket.assigns.image_count)

    next_image = Enum.at(socket.assigns.images, next_index)

    image_name = String.split(next_image, "/") |> Enum.reverse() |> hd()
    # image_url = "/images/slides/#{image_name}"

    socket =
      socket
      |> assign(:curr_index, next_index)
      # |> assign(:image_url, image_url)
      |> push_patch(to: "/jury_viewer?img=#{image_name}")

    {:noreply, socket}
  end

  def handle_event("vote", %{"vote" => vote}, socket) do
    {int_vote, ""} = Integer.parse(vote)
    IO.inspect(int_vote, label: :voted)
    # next_image = Enum.at(socket.assigns.images, socket.assigns.curr_index)
    # image_name = String.split(next_image, "/") |> Enum.reverse() |> hd()

    socket =
      socket
      |> add_vote(int_vote)

    # # Note: remember events pushed from the server via push_event are global
    # # and will be dispatched to all active hooks on the client who are handling that event.
    # |> push_event("new-image", %{options: %{image_url: "/images/slides/#{image_name}"}})

    {:noreply, socket}
  end

  def handle_event("prize", %{"prize" => prize}, socket) do
    IO.inspect(prize, label: :prize)
    {:noreply, socket}
  end

  def handle_event("vote-key", %{"key" => vote}, socket) do
    case Integer.parse(vote) do
      {int_vote, ""} ->
        IO.inspect(int_vote, label: :key_voted)
        {:noreply, add_vote(socket, int_vote)}

      :error ->
        IO.puts("Invalid key: #{vote}")
        {:noreply, socket}
    end
  end

  def handle_event("clear-votes", %{}, socket) do
    {:noreply, assign(socket, :given_votes, [])}
  end

  def handle_event(event, data, socket) do
    IO.puts("Received event '#{event}' with data '#{inspect(data)}'")
    {:noreply, socket}
  end

  defp add_vote(socket, vote) do
    assign(socket, :given_votes, socket.assigns.given_votes ++ [vote])
  end

  # defp generate_random_images(amount) do
  #   Enum.map(1..amount, fn index ->
  #     width = Enum.random(200..1000)
  #     height = Enum.random(200..1000)

  #     url =
  #       @lorempicsum_url
  #       |> URI.parse()
  #       |> URI.merge("/seed/#{index}/#{width}/#{height}")
  #       |> URI.to_string()

  #     {url, width, height}
  #   end)
  # end
end
