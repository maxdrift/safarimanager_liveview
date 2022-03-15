defmodule SMWeb.Jury do
  @moduledoc """
  Live view to handle Jury operations i.e. evaluation of Slides
  """
  use SMWeb, :surface_jury_view

  alias SM.Competitions
  alias SM.Slides

  alias SMWeb.Atoms.JuryToolbarButton

  @votes %{
    votes: [-100, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    prizes: ["distinguish"]
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # evaluations =

    socket =
      socket
      |> assign(:curr_index, 0)
      |> assign(:image_count, 0)
      |> assign(:votes, @votes.votes)
      |> assign(:prizes, @votes.prizes)
      |> assign(:given_votes, [])

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id, "slide_id" => slide_id}, _url, socket) do
    socket =
      if Map.has_key?(socket.assigns, :competition) do
        socket
      else
        {:ok, competition} = Competitions.get(competition_id)

        assign(socket, :competition, competition)
      end

    socket =
      if Map.has_key?(socket.assigns, :slides) do
        socket
      else
        slides = Slides.list(competition_id)

        assign(socket, :slides, slides)
      end

    slides = socket.assigns.slides

    slide = Enum.find(slides, &(&1.id == slide_id))
    current_index = Enum.find_index(slides, &(&1.id == slide_id))
    # {:ok, slide} = Slides.get(slide_id)
    file_path = image_path(socket, slide)

    # Note: remember events pushed from the server via push_event are global
    # and will be dispatched to all active hooks on the client who are handling that event.
    socket =
      socket
      # |> assign(:competition, competition)
      # |> assign(:slides, slides)
      |> assign(:image_count, Enum.count(slides))
      |> assign(:curr_index, current_index)
      |> assign(:subject_name, String.capitalize(slide.subject.name))
      |> push_event("new-image", %{options: %{image_url: file_path}})

    {:noreply, socket}
  end

  @doc """
  Entry point
  """
  def handle_params(%{"competition_id" => competition_id}, _url, socket) do
    {:ok, competition} = Competitions.get(competition_id)
    slides = Slides.list(competition_id)

    socket =
      socket
      |> assign(:competition, competition)
      |> assign(:slides, slides)

    # |> assign(:image_count, Enum.count(slides))

    next_slide = Enum.at(slides, 0)
    # file_path = image_path(socket, next_slide)

    socket = push_patch(socket, to: "#{full_path(socket)}?slide_id=#{next_slide.id}")

    # Note: remember events pushed from the server via push_event are global
    # and will be dispatched to all active hooks on the client who are handling that event.
    # |> push_event("new-image", %{options: %{image_url: file_path}})

    {:noreply, socket}
  end

  # @spec handle_event(String.t(), %{String.t() => any()}, Socket.t()) :: {:noreply, Socket.t()}
  @impl Phoenix.LiveView
  def handle_event("next-image", _data, socket) do
    next_index = rem(socket.assigns.curr_index + 1, socket.assigns.image_count)
    next_slide = Enum.at(socket.assigns.slides, next_index)

    socket =
      socket
      |> assign(:curr_index, next_index)
      # |> assign(:image_url, image_url)
      |> push_patch(to: "#{full_path(socket)}?slide_id=#{next_slide.id}")

    {:noreply, socket}
  end

  def handle_event("prev-image", _data, socket) do
    next_index = rem(socket.assigns.curr_index - 1, socket.assigns.image_count)
    next_slide = Enum.at(socket.assigns.slides, next_index)

    socket =
      socket
      |> assign(:curr_index, next_index)
      # |> assign(:image_url, image_url)
      |> push_patch(to: "#{full_path(socket)}?slide_id=#{next_slide.id}")

    {:noreply, socket}
  end

  def handle_event("vote", %{"vote" => vote}, socket) do
    {int_vote, ""} = Integer.parse(vote)
    IO.inspect(int_vote, label: :voted)
    # next_image = Enum.at(socket.assigns.slides, socket.assigns.curr_index)
    # image_name = String.split(next_image, "/") |> Enum.reverse() |> hd()

    socket = add_vote(socket, int_vote)

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
    votes = Enum.reverse([vote | socket.assigns.given_votes])
    assign(socket, :given_votes, votes)
  end

  defp full_path(socket) do
    "/organize/#{socket.assigns.competition.id}/jury"
  end

  defp image_path(socket, slide) do
    uploads_path = Slides.get_uploads_path(slide.competition_id, slide.user_id)

    socket
    |> Routes.static_path(uploads_path)
    |> Path.join(slide.file_name)
  end
end
