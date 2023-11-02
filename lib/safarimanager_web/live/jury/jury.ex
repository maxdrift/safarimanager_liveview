defmodule SMWeb.Live.Jury do
  @moduledoc """
  Live view to handle Jury operations i.e. evaluation of Slides
  """
  use SMWeb, :surface_view

  alias SM.Cache
  alias SM.Competitions
  alias SM.Slides
  alias SM.Utils
  alias SMWeb.Components.JuryToolbarButton

  require Logger

  @evaluations %{
    prizes: ["distinguish"]
  }

  @jurors_ping_interval 5

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = if connected?(socket), do: Slides.subscribe()

    socket =
      assign(socket,
        category: "all",
        curr_index: 0,
        image_count: 0,
        flash_eval: nil,
        prizes: @evaluations.prizes,
        curr_slide: nil,
        evaluations: [],
        ping_reference: nil
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id, "slide_id" => slide_id} = params, _url, socket) do
    :ok = Phoenix.PubSub.subscribe(SM.PubSub, "#{competition_id}-jury")
    category = Map.get(params, "category", "all")

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
        slides = Slides.list_for_jury(competition_id, category)

        assign(socket, :slides, slides)
      end

    slides = socket.assigns.slides

    slide = Enum.find(slides, &(&1.id == slide_id))
    current_index = Enum.find_index(slides, &(&1.id == slide_id))
    file_path = Utils.slide_path(slide)
    image_count = Enum.count(slides)

    socket =
      socket
      |> assign(
        image_count: image_count,
        curr_index: current_index,
        curr_slide: slide,
        category: category,
        evaluations: socket.assigns.competition.allowed_evaluations,
        penalty_votes: MapSet.new()
      )
      |> assign(:jurors, socket.assigns.competition.jurors)
      # Note: remember events pushed from the server via push_event are global
      # and will be dispatched to all active hooks on the client who are handling that event.
      |> push_event("new-image", %{options: %{image_url: file_path}})

    Cache.put("#{competition_id}_#{category}_current_jury_slide_id", slide_id)

    :ok = broadcast_current_slide(competition_id, slide_id, image_count, current_index)

    ping_reference =
      socket.assigns.ping_reference || Process.send_after(self(), :ping_remote_juror, @jurors_ping_interval * 1000)

    socket = assign(socket, ping_reference: ping_reference)

    # schedule_next_image(5)

    {:noreply, socket}
  end

  @doc """
  Entry point
  """
  def handle_params(%{"competition_id" => competition_id} = params, _url, socket) do
    category = Map.get(params, "category", "all")
    {:ok, competition} = Competitions.get(competition_id)
    slides = Slides.list_for_jury(competition_id, category)

    socket =
      assign(socket, competition: competition, slides: slides, category: category)

    next_slide_id =
      with slide_id when not is_nil(slide_id) <-
             Cache.get("#{competition_id}_#{category}_current_jury_slide_id"),
           {:ok, slide} <- Slides.get(slide_id),
           true <- slide.status == :submitted_jury do
        slide.id
      else
        nil ->
          Logger.info("Current jury slide_id cache miss")

          slides
          |> Enum.at(0, %{})
          |> Map.get(:id)

        {:error, :not_found} ->
          Logger.warning("Cached jury slide_id not found")

          slides
          |> Enum.at(0, %{})
          |> Map.get(:id)

        false ->
          Logger.warning("Cached jury slide_id is not in 'submitted_jury' status")

          slides
          |> Enum.at(0, %{})
          |> Map.get(:id)
      end

    socket =
      if next_slide_id do
        push_patch(socket,
          to: "#{full_path(socket)}?category=#{category}&slide_id=#{next_slide_id}"
        )
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
    Logger.debug("Prize: #{inspect(prize)}")
    {:noreply, socket}
  end

  def handle_event("penalty", _params, socket) do
    slide_id = socket.assigns.curr_slide.id

    {:ok, _slide} =
      if Slides.has_penalty?(slide_id) do
        {:ok, _slide} = Slides.clear_penalty(slide_id)
      else
        {:ok, _slide} = Slides.apply_penalty(slide_id)
      end

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

  def handle_event("evaluation-key", %{"key" => "Escape"}, socket) do
    {:noreply, redirect(socket, to: "/organize/#{socket.assigns.competition.id}/jury_launcher")}
  end

  def handle_event("evaluation-key", %{"key" => evaluation}, socket) do
    case Enum.find(socket.assigns.evaluations, &(&1.name == evaluation)) do
      %_evaluation{} = match ->
        socket = evaluate(socket, match.id)
        Logger.debug("Evaluation #{match.name} with value #{match.value} and ID #{match.id}")
        {:noreply, socket}

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
    {:ok, _slide} = Slides.clear_evaluations(socket.assigns.curr_slide.id)
    {:ok, _slide} = Slides.clear_penalty(socket.assigns.curr_slide.id)

    {:noreply, socket}
  end

  def handle_event(event, data, socket) do
    Logger.debug("Received event '#{event}' with data '#{inspect(data)}'")
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _action], _result}, socket) do
    curr_slide_id = socket.assigns.curr_slide.id
    {:ok, updated_slide} = Slides.get(curr_slide_id)
    slides = Slides.list_for_jury(socket.assigns.competition.id, socket.assigns.category)

    socket = set_flash_evaluation(socket, updated_slide)

    socket =
      socket
      |> assign(:curr_slide, updated_slide)
      |> assign(:slides, slides)

    :ok =
      broadcast_current_slide(
        socket.assigns.competition.id,
        socket.assigns.curr_slide.id,
        socket.assigns.image_count,
        socket.assigns.curr_index
      )

    {:noreply, socket}
  end

  def handle_info(:unset_flash_eval, socket) do
    socket = assign(socket, :flash_eval, nil)

    {:noreply, socket}
  end

  def handle_info(:next_slide, socket) do
    socket = to_next_image(socket)

    {:noreply, socket}
  end

  def handle_info(:ping_remote_juror, socket) do
    Logger.debug("Sending ping to remote jurors...")

    :ok =
      broadcast_current_slide(
        socket.assigns.competition.id,
        socket.assigns.curr_slide.id,
        socket.assigns.image_count,
        socket.assigns.curr_index
      )

    Process.send_after(self(), :ping_remote_juror, @jurors_ping_interval * 1000)

    {:noreply, socket}
  end

  def handle_info({:evaluate_slide, slide_id, user_id, evaluation_id}, socket) do
    _result = Slides.evaluate_by_juror(socket.assigns.competition.id, slide_id, user_id, evaluation_id)
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Internal

  defp set_flash_evaluation(socket, slide) do
    evaluations_str = Enum.map_join(slide.votes, "-", & &1.evaluation.name)
    socket = assign(socket, :flash_eval, evaluations_str)
    {:ok, _tref} = :timer.send_after(5000, :unset_flash_eval)

    socket
  end

  defp evaluate(socket, evaluation_id) do
    slide_id = socket.assigns.curr_slide.id

    case Slides.evaluate(socket.assigns.competition.id, slide_id, evaluation_id) do
      :ok ->
        socket

      {:error, :already_evaluated} ->
        socket

      {:error, reason} ->
        Logger.error("Error saving evaluation: #{inspect(reason)}")
        put_flash(socket, :error, gettext("Unexpected error while saving evaluation"))
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
    |> push_patch(to: "#{full_path(socket)}?category=#{socket.assigns.category}&slide_id=#{next_slide.id}")
  end

  defp full_path(socket) do
    "/organize/#{socket.assigns.competition.id}/jury"
  end

  defp can_evaluate?(_competition, nil), do: false

  defp can_evaluate?(competition, slide) do
    Enum.count(slide.evaluations) <
      Enum.count(competition.jurors) * competition.settings.evaluations_per_juror
  end

  defp broadcast_current_slide(competition_id, slide_id, image_count, curr_index) do
    Phoenix.PubSub.broadcast(SM.PubSub, "#{competition_id}-jury", %{
      curr_slide: slide_id,
      image_count: image_count,
      curr_index: curr_index,
      jury_pid: self()
    })
  end

  # defp schedule_next_image(seconds) do
  #   Process.send_after(self(), :next_slide, seconds * 1000)
  # end
end
