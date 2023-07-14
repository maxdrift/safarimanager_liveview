defmodule SMWeb.Live.Validation do
  @moduledoc """
  Live view to handle Validation operations
  """
  use SMWeb, :surface_view

  alias SM.Cache
  alias SM.Competitions
  alias SM.Slides
  alias SM.Subjects
  alias SMWeb.Components.JuryToolbarButton
  alias Surface.Components.Form
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.TextInput

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = if connected?(socket), do: Slides.subscribe()

    socket =
      socket
      |> assign(:curr_index, 0)
      |> assign(:image_count, 0)
      |> assign(:curr_slide, nil)
      |> assign(:subjects, Subjects.list())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(
        %{"competition_id" => competition_id, "slide_id" => slide_id},
        _url,
        socket
      ) do
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
        slides = Slides.list_for_validation(competition_id)

        assign(socket, :slides, slides)
      end

    slides = socket.assigns.slides

    slide = Enum.find(slides, &(&1.id == slide_id))
    current_index = Enum.find_index(slides, &(&1.id == slide_id))
    file_path = image_path(slide)

    socket =
      socket
      |> assign(:image_count, Enum.count(slides))
      |> assign(:curr_index, current_index)
      |> assign(:curr_slide, slide)
      # Note: remember events pushed from the server via push_event are global
      # and will be dispatched to all active hooks on the client who are handling that event.
      |> push_event("new-image", %{options: %{image_url: file_path}})

    Cache.put("#{competition_id}_current_validation_slide_id", slide_id)

    {:noreply, socket}
  end

  @doc """
  Entry point
  """
  def handle_params(%{"competition_id" => competition_id}, _url, socket) do
    {:ok, competition} = Competitions.get(competition_id)
    slides = Slides.list_for_validation(competition_id)

    socket =
      socket
      |> assign(:competition, competition)
      |> assign(:slides, slides)

    next_slide_id =
      case Cache.get("#{competition_id}_current_validation_slide_id") do
        nil ->
          slides
          |> Enum.at(0, %{})
          |> Map.get(:id)

        resumed_slide_id ->
          resumed_slide_id
      end

    socket =
      if next_slide_id do
        push_patch(socket, to: "#{full_path(socket)}?slide_id=#{next_slide_id}")
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

  # TODO: improve form reset when changing slide
  def handle_event(
        "validate",
        %{"wrong_subject_flag" => %{"subject" => subject_id}},
        socket
      ) do
    slide_id = socket.assigns.curr_slide.id
    {:ok, slide} = Slides.get(slide_id)

    flag_params =
      if slide.subject_id != subject_id do
        %{
          "wrong_subject" => true,
          "wrong_subject_ctx" => %{"from" => slide.subject_id, "to" => subject_id}
        }
      else
        %{
          "wrong_subject" => false,
          "wrong_subject_ctx" => nil
        }
      end

    case Slides.update(slide, %{
           "flags" => flag_params
         }) do
      {:ok, slide} ->
        :ok

        {:noreply, assign(socket, :curr_slide, slide)}

      {:error, reason} ->
        Logger.error("Unable to update Slide: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  # TODO: improve form reset when changing slide
  def handle_event("validate", %{"other_reason_flag" => %{"reason" => reason}}, socket) do
    slide_id = socket.assigns.curr_slide.id
    {:ok, slide} = Slides.get(slide_id)
    trimmed_reason = String.trim(reason)

    flag_params =
      if trimmed_reason == "" do
        %{
          "other_reason" => false,
          "other_reason_ctx" => nil
        }
      else
        %{
          "other_reason" => true,
          "other_reason_ctx" => trimmed_reason
        }
      end

    :ok =
      case Slides.update(slide, %{"flags" => flag_params}) do
        {:ok, _slide} ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to update Slide: #{inspect(reason)}")
          error
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
    {:noreply,
     redirect(socket,
       to: "/organize/#{socket.assigns.competition.id}/validation_launcher"
     )}
  end

  def handle_event(event, data, socket) do
    Logger.debug("Received event '#{event}' with data '#{inspect(data)}'")
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _action], _result}, socket) do
    curr_slide_id = socket.assigns.curr_slide.id
    {:ok, updated_slide} = Slides.get(curr_slide_id)
    slides = Slides.list_for_validation(socket.assigns.competition.id)

    socket =
      socket
      |> assign(:curr_slide, updated_slide)
      |> assign(:slides, slides)

    {:noreply, socket}
  end

  # Internal

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
    "/organize/#{socket.assigns.competition.id}/validation"
  end

  defp image_path(slide) do
    ~p"/uploads/#{slide.competition_id}/#{slide.user_id}/#{slide.file_name}"
  end

  defp status_to_label(:submitted_fixed), do: gettext("Fixed points")
  defp status_to_label(:submitted_jury), do: gettext("Jury")
end
