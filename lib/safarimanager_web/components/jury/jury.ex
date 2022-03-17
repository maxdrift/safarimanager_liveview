defmodule SMWeb.Jury do
  @moduledoc """
  Live view to handle Jury operations i.e. evaluation of Slides
  """
  use SMWeb, :surface_jury_view

  alias SM.Competitions
  alias SM.Slides

  alias SMWeb.Atoms.JuryToolbarButton

  @evaluations %{
    prizes: ["distinguish"]
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Slides.subscribe()

    socket =
      socket
      |> assign(:curr_index, 0)
      |> assign(:image_count, 0)
      |> assign(:prizes, @evaluations.prizes)

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
    file_path = image_path(socket, slide)

    socket =
      socket
      |> assign(:image_count, Enum.count(slides))
      |> assign(:curr_index, current_index)
      |> assign(:curr_slide, slide)
      |> assign(:evaluations, socket.assigns.competition.allowed_evaluations)
      |> assign(:jurors, socket.assigns.competition.jurors)
      |> assign(:jurors_index, 0)
      # Note: remember events pushed from the server via push_event are global
      # and will be dispatched to all active hooks on the client who are handling that event.
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

    next_slide = Enum.at(slides, 0)

    socket = push_patch(socket, to: "#{full_path(socket)}?slide_id=#{next_slide.id}")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("next-image", _data, socket) do
    next_index = rem(socket.assigns.curr_index + 1, socket.assigns.image_count)
    next_slide = Enum.at(socket.assigns.slides, next_index)

    socket =
      socket
      |> assign(:curr_index, next_index)
      |> push_patch(to: "#{full_path(socket)}?slide_id=#{next_slide.id}")

    {:noreply, socket}
  end

  def handle_event("prev-image", _data, socket) do
    next_index = rem(socket.assigns.curr_index - 1, socket.assigns.image_count)
    next_slide = Enum.at(socket.assigns.slides, next_index)

    socket =
      socket
      |> assign(:curr_index, next_index)
      |> push_patch(to: "#{full_path(socket)}?slide_id=#{next_slide.id}")

    {:noreply, socket}
  end

  def handle_event("evaluate", %{"evaluation-id" => evaluation_id}, socket) do
    juror = Enum.at(socket.assigns.jurors, socket.assigns.jurors_index)

    {:ok, _slide_evaluation} =
      Slides.evaluate(socket.assigns.curr_slide.id, juror.id, evaluation_id)

    socket = assign(socket, :jurors_index, socket.assigns.jurors_index + 1)

    {:noreply, socket}
  end

  def handle_event("prize", %{"prize" => prize}, socket) do
    IO.inspect(prize, label: :prize)
    {:noreply, socket}
  end

  def handle_event("evaluation-key", %{"key" => evaluation}, socket) do
    case Integer.parse(evaluation) do
      {int_evaluation, ""} ->
        IO.inspect(int_evaluation, label: :key_evaluationd)
        {:noreply, socket}

      :error ->
        IO.puts("Invalid key: #{evaluation}")
        {:noreply, socket}
    end
  end

  def handle_event("clear-evaluations", %{}, socket) do
    Slides.clear_evaluations(socket.assigns.curr_slide.id)
    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    IO.puts("Received event '#{event}' with data '#{inspect(data)}'")
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, action], result}, socket) do
    IO.inspect(action, label: :action)
    IO.inspect(result, label: :result)

    curr_slide_id = socket.assigns.curr_slide.id
    {:ok, updated_slide} = Slides.get(curr_slide_id)

    socket = assign(socket, :curr_slide, updated_slide)

    {:noreply, socket}
  end

  # Internal

  defp full_path(socket) do
    "/organize/#{socket.assigns.competition.id}/jury"
  end

  defp image_path(socket, slide) do
    uploads_path = Slides.get_uploads_path(slide.competition_id, slide.user_id)

    socket
    |> Routes.static_path(uploads_path)
    |> Path.join(slide.file_name)
  end

  defp can_evaluate?(competition, slide) do
    Enum.count(slide.evaluations) <
      Enum.count(competition.jurors) * competition.evaluations_per_juror
  end
end
