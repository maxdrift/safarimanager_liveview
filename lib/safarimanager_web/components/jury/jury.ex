defmodule SMWeb.Jury do
  @moduledoc """
  Live view to handle Jury operations i.e. evaluation of Slides
  """
  use SMWeb, :surface_jury_view

  alias SM.Competitions
  alias SM.Slides

  alias SMWeb.Atoms.JuryToolbarButton

  require Logger

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
      |> assign(:flash_eval, nil)
      |> assign(:prizes, @evaluations.prizes)
      |> assign(:curr_slide, nil)
      |> assign(:evaluations, [])

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

    socket =
      if next_slide do
        push_patch(socket, to: "#{full_path(socket)}?slide_id=#{next_slide.id}")
      else
        assign(socket, :curr_slide, nil)
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("next-image", _data, socket) do
    {:noreply, to_next_image(socket)}
  end

  def handle_event("prev-image", _data, socket) do
    {:noreply, to_prev_image(socket)}
  end

  def handle_event("evaluate", %{"evaluation-id" => evaluation_id}, socket) do
    socket = evaluate(socket, evaluation_id)

    {:noreply, socket}
  end

  def handle_event("prize", %{"prize" => prize}, socket) do
    IO.inspect(prize, label: :prize)
    {:noreply, socket}
  end

  def handle_event("evaluation-key", %{"key" => "ArrowLeft"}, socket) do
    {:noreply, to_prev_image(socket)}
  end

  def handle_event("evaluation-key", %{"key" => "ArrowRight"}, socket) do
    {:noreply, to_next_image(socket)}
  end

  def handle_event("evaluation-key", %{"key" => "Home"}, socket) do
    {:noreply, to_first_image(socket)}
  end

  def handle_event("evaluation-key", %{"key" => "End"}, socket) do
    {:noreply, to_last_image(socket)}
  end

  def handle_event("evaluation-key", %{"key" => "PageUp"}, socket) do
    {:noreply, to_prev_subject(socket)}
  end

  def handle_event("evaluation-key", %{"key" => "PageDown"}, socket) do
    {:noreply, to_next_subject(socket)}
  end

  def handle_event("evaluation-key", %{"key" => evaluation}, socket) do
    with {int_evaluation, ""} <- Integer.parse(evaluation),
         %_evaluation{} = match <-
           Enum.find(
             socket.assigns.evaluations,
             &Decimal.equal?(&1.value, Decimal.new(int_evaluation))
           ) do
      socket = evaluate(socket, match.id)
      Logger.debug("Evaluation value #{match.value} with ID #{match.id}")
      {:noreply, socket}
    else
      :error ->
        Logger.info("Invalid key: #{evaluation}")
        {:noreply, socket}

      nil ->
        Logger.info("Invalid key: #{evaluation}")
        {:noreply, socket}

      {:error, _reason} ->
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
  def handle_info({Slides, [:slide, _action], _result}, socket) do
    curr_slide_id = socket.assigns.curr_slide.id
    {:ok, updated_slide} = Slides.get(curr_slide_id)

    socket = assign(socket, :curr_slide, updated_slide)

    {:noreply, socket}
  end

  def handle_info(:unset_flash_eval, socket) do
    socket = assign(socket, :flash_eval, nil)

    {:noreply, socket}
  end

  # Internal

  defp set_flash_evaluation(socket, value) do
    socket = assign(socket, :flash_eval, value)
    {:ok, _tref} = :timer.send_after(5000, :unset_flash_eval)

    socket
  end

  defp evaluate(socket, evaluation_id) do
    case Slides.evaluate(
           socket.assigns.competition.id,
           socket.assigns.curr_slide.id,
           evaluation_id
         ) do
      {:ok, slide_evaluation} ->
        set_flash_evaluation(socket, slide_evaluation.evaluation.value)

      {:error, :already_evaluated} ->
        socket

      {:error, reason} ->
        Logger.error("Error storing evaluation: #{inspect(reason)}")
        socket
    end
  end

  defp to_prev_image(socket) do
    next_index = rem(socket.assigns.curr_index - 1, socket.assigns.image_count)
    to_image_index(socket, next_index)
  end

  defp to_next_image(socket) do
    next_index = rem(socket.assigns.curr_index + 1, socket.assigns.image_count)
    to_image_index(socket, next_index)
  end

  defp to_first_image(socket) do
    to_image_index(socket, 0)
  end

  defp to_last_image(socket) do
    to_image_index(socket, socket.assigns.image_count - 1)
  end

  defp to_prev_subject(socket) do
    curr_slide = Enum.at(socket.assigns.slides, socket.assigns.curr_index)
    curr_subject_id = curr_slide.subject_id

    {rev_next_slides, rev_prev_slides} =
      socket.assigns.slides
      |> Enum.reverse()
      |> Enum.split(-socket.assigns.curr_index)

    next_index =
      rev_prev_slides
      |> Enum.concat(rev_next_slides)
      |> Enum.find_index(&(&1.subject_id != curr_subject_id))

    last_image_index = rem(socket.assigns.curr_index - next_index - 1, socket.assigns.image_count)

    # Repeat to find the first image of the current subject

    curr_slide = Enum.at(socket.assigns.slides, last_image_index)
    curr_subject_id = curr_slide.subject_id

    {rev_next_slides, rev_prev_slides} =
      socket.assigns.slides
      |> Enum.reverse()
      |> Enum.split(-last_image_index)

    next_index =
      rev_prev_slides
      |> Enum.concat(rev_next_slides)
      |> Enum.find_index(&(&1.subject_id != curr_subject_id))

    next_index = rem(last_image_index - next_index, socket.assigns.image_count)
    to_image_index(socket, next_index)
  end

  defp to_next_subject(socket) do
    curr_subject_id = socket.assigns.curr_slide.subject_id

    {prev_slides, next_slides} = Enum.split(socket.assigns.slides, socket.assigns.curr_index)

    next_index =
      next_slides
      |> Enum.concat(prev_slides)
      |> Enum.find_index(&(&1.subject_id != curr_subject_id))

    next_index = rem(socket.assigns.curr_index + next_index, socket.assigns.image_count)
    to_image_index(socket, next_index)
  end

  defp to_image_index(socket, index) do
    next_slide = Enum.at(socket.assigns.slides, index)

    socket
    |> assign(:curr_index, index)
    |> push_patch(to: "#{full_path(socket)}?slide_id=#{next_slide.id}")
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

  defp can_evaluate?(competition, nil), do: false

  defp can_evaluate?(competition, slide) do
    Enum.count(slide.evaluations) <
      Enum.count(competition.jurors) * competition.evaluations_per_juror
  end
end
