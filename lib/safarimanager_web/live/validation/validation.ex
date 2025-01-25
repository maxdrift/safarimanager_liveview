defmodule SMWeb.Live.Validation do
  @moduledoc """
  Live view to handle Validation operations
  """
  use SMWeb, :surface_view

  import SMWeb.Components.JuryToolbarButton

  alias SM.Cache
  alias SM.Competitions
  alias SM.Slides
  alias SM.Subjects
  alias SM.Utils
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.NumberInput
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
        slides = Slides.list_for_validation(competition_id)

        assign(socket, :slides, slides)
      end

    slides = socket.assigns.slides

    slide = Enum.find(slides, &(&1.id == slide_id))
    current_index = Enum.find_index(slides, &(&1.id == slide_id))
    file_path = Utils.slide_path(slide)

    socket =
      socket
      |> assign(
        image_count: Enum.count(slides),
        curr_index: current_index,
        curr_slide: slide,
        slide_flags: Slides.slide_flags_by_types(slide)
      )
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
      with slide_id when not is_nil(slide_id) <-
             Cache.get("#{competition_id}_current_validation_slide_id"),
           {:ok, slide} <- Slides.get(slide_id),
           true <- slide.status in [:submitted_jury, :submitted_fixed] do
        slide.id
      else
        nil ->
          Logger.info("Current validation slide_id cache miss")

          slides
          |> Enum.at(0, %{})
          |> Map.get(:id)

        {:error, :not_found} ->
          Logger.warning("Cached validation slide_id not found")

          slides
          |> Enum.at(0, %{})
          |> Map.get(:id)

        false ->
          Logger.warning("Cached validation slide_id is not in 'submitted' status")

          slides
          |> Enum.at(0, %{})
          |> Map.get(:id)
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

  def handle_event(
        "wrong-subject-change",
        %{"wrong_subject_flag" => %{"new_subject" => new_subject_id, "flag_id" => flag_id}},
        socket
      ) do
    old_subject_id = socket.assigns.curr_slide.subject_id

    socket =
      if new_subject_id == old_subject_id do
        if flag_id do
          {:ok, slide_flag} = Slides.get_slide_flag(flag_id)
          {:ok, _slide_flag} = Slides.remove_slide_flag(slide_flag)
          # TODO: Remove in favor of handle_info callback
          assign(socket, slide_flags: Map.put(socket.assigns.slide_flags, :wrong_subject, nil))
        else
          socket
        end
      else
        if flag_id == "" do
          {:ok, slide_flag} =
            Slides.add_slide_flag(%{
              "slide_id" => socket.assigns.curr_slide.id,
              "type" => :wrong_subject,
              "context" => %{"from" => old_subject_id, "to" => new_subject_id}
            })

          assign(socket,
            slide_flags: Map.put(socket.assigns.slide_flags, :wrong_subject, slide_flag)
          )
        else
          {:ok, slide_flag} = Slides.get_slide_flag(flag_id)

          {:ok, slide_flag} =
            Slides.update_slide_flag(slide_flag, %{
              "context" => %{"from" => old_subject_id, "to" => new_subject_id}
            })

          assign(socket,
            slide_flags: Map.put(socket.assigns.slide_flags, :wrong_subject, slide_flag)
          )
        end
      end

    {:noreply, socket}
  end

  def handle_event("unrecognizable-submit", %{"unrecognizable" => %{"flag_id" => flag_id}}, socket) do
    slide_flag =
      if flag_id == "" do
        {:ok, slide_flag} =
          Slides.add_slide_flag(%{
            "slide_id" => socket.assigns.curr_slide.id,
            "type" => :unrecognizable
          })

        slide_flag
      else
        {:ok, slide_flag} = Slides.get_slide_flag(flag_id)

        {:ok, _slide_flag} = Slides.remove_slide_flag(slide_flag)
        nil
      end

    {:noreply, assign(socket, slide_flags: Map.put(socket.assigns.slide_flags, :unrecognizable, slide_flag))}
  end

  def handle_event("distinction-submit", %{"distinction" => %{"flag_id" => flag_id}}, socket) do
    slide_flag =
      if flag_id == "" do
        {:ok, slide_flag} =
          Slides.add_slide_flag(%{
            "slide_id" => socket.assigns.curr_slide.id,
            "type" => :distinction
          })

        slide_flag
      else
        {:ok, slide_flag} = Slides.get_slide_flag(flag_id)

        {:ok, _slide_flag} = Slides.remove_slide_flag(slide_flag)
        nil
      end

    {:noreply, assign(socket, slide_flags: Map.put(socket.assigns.slide_flags, :distinction, slide_flag))}
  end

  def handle_event("note-change", %{"note" => %{"value" => value, "flag_id" => flag_id}}, socket) do
    slide_flag =
      if flag_id == "" do
        {:ok, slide_flag} =
          Slides.add_slide_flag(%{
            "slide_id" => socket.assigns.curr_slide.id,
            "type" => :note,
            "context" => %{"message" => String.trim(value)}
          })

        slide_flag
      else
        {:ok, slide_flag} = Slides.get_slide_flag(flag_id)

        if String.trim(value) == "" do
          {:ok, _slide_flag} =
            Slides.remove_slide_flag(slide_flag)

          nil
        else
          {:ok, slide_flag} =
            Slides.update_slide_flag(slide_flag, %{
              "context" => %{"message" => String.trim(value)}
            })

          slide_flag
        end
      end

    {:noreply, assign(socket, slide_flags: Map.put(socket.assigns.slide_flags, :note, slide_flag))}
  end

  def handle_event("go-to-change", %{"go_to" => %{"go_to" => index}}, socket) do
    case String.to_integer(index) do
      new_index when new_index >= 1 and new_index <= socket.assigns.image_count ->
        {:noreply, to_image_index(socket, new_index - 1)}

      new_index when new_index <= 1 ->
        {:noreply, to_first_image(socket)}

      new_index when new_index >= socket.assigns.image_count ->
        {:noreply, to_last_image(socket)}

      _invalid_index ->
        {:noreply, socket}
    end
  rescue
    ArgumentError ->
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

  def handle_info({Slides, [:slide_flag, _action], _result}, socket) do
    # TODO: Refactor using Phoenix streams and replacing slide flags efficiently
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

  defp status_to_label(:submitted_fixed), do: gettext("Fixed points")
  defp status_to_label(:submitted_jury), do: gettext("Jury")

  defp maybe_show_wrong_subject_label(js, slide_flags) do
    if slide_flags.wrong_subject do
      JS.show(js, to: "#wrong-subject-label")
    else
      js
    end
  end
end
