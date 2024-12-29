defmodule SMWeb.Live.BallotBox do
  @moduledoc """
  Ballot box live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Evaluations
  alias SM.Jurors
  alias SM.Slides

  require Logger

  # This should be bigger than the ping interval in live/jury/jury.ex
  # to avoid screen flickering with the "voting not available yet" modal.
  @watchdog_seconds 8

  @impl Phoenix.LiveView
  def render(assigns) do
    ~F"""
    {#if is_nil(@slide)}
      <div class="fixed top-0 bottom-0 left-0 right-0 z-50 bg-base-300/60 text-center flex justify-center items-center">
        <div>
          <span class="text-lg mx-4">{gettext("Voting not available yet. Wait for the Jury session to start!")}</span>
          <div class="mt-4">
            <span class="loading loading-spinner loading-lg" />
          </div>
        </div>
      </div>
    {#elseif !@can_vote_slide}
      <div class="fixed top-0 bottom-0 left-0 right-0 z-50 bg-base-300/60 text-center flex flex-col justify-center items-center">
        <div>
          <span class="text-lg mx-4">{gettext("You have voted on slide") <> " #{@curr_index + 1}"}</span>
        </div>
        <div>
          <span class="text-lg mx-4">{gettext("Please wait for the next slide.")}</span>
        </div>
        <div>
          <Heroicons.icon name="check-circle" type="outline" class="h-20 w-20 stroke-success" />
        </div>
      </div>
    {#elseif @selected_evaluation}
      <div class="fixed top-0 bottom-0 left-0 right-0 z-50 bg-base-300/60 text-center flex justify-center items-center">
        <div class="flex flex-col gap-1">
          <span>{gettext("Selected vote:")}</span> <span class="text-2xl bold mb-2">{@selected_evaluation.name}</span>
          <div>
            <button class="btn btn-primary" :on-click="confirm-vote">
              <span>{gettext("Confirm")}</span>
            </button>
            <button class="btn btn-error" :on-click="dismiss-vote">
              <span>{gettext("Cancel")}</span>
            </button>
          </div>
        </div>
      </div>
    {/if}
    <div
      id="voting-pad"
      class={"blur-sm": is_nil(@slide) || @selected_evaluation || !@can_vote_slide}
      phx-hook="NoSleep"
    >
      <div class="my-4 text-center min-h-6">
        {#if @slide}
          <span class="capitalize">{@slide && @slide.subject.name}</span> - {gettext("slide")} {@curr_index + 1} {gettext("of")} {@image_count}
        {/if}
      </div>
      <div class="grid grid-cols-3 grid-rows-4 gap-1">
        {#for evaluation <- @evaluations}
          <button
            class="btn btn-lg btn-neutral"
            :on-click="select-vote"
            :values={evaluation_id: evaluation.id}
          >
            <span>{evaluation.name}</span>
          </button>
        {#else}
          <span>{gettext("No evaluations available")}</span>
        {/for}
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        competition: nil,
        user_id: nil,
        evaluations: [],
        slide: nil,
        image_count: 0,
        curr_index: 0,
        can_vote_slide: true,
        selected_evaluation: nil,
        watchdog_ref: nil,
        jury_pid: nil
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("select-vote", %{"evaluation-id" => evaluation_id}, socket) do
    {:ok, evaluation} = Evaluations.get(evaluation_id)

    socket = assign(socket, selected_evaluation: evaluation)

    {:noreply, socket}
  end

  def handle_event("confirm-vote", _params, socket) do
    send(
      socket.assigns.jury_pid,
      {:evaluate_slide, socket.assigns.slide.id, socket.assigns.user_id, socket.assigns.selected_evaluation.id}
    )

    socket = assign(socket, selected_evaluation: nil)

    {:noreply, socket}
  end

  def handle_event("dismiss-vote", _params, socket) do
    socket = assign(socket, selected_evaluation: nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id, "user_id" => user_id}, _uri, socket) do
    {:ok, competition} = Competitions.get(competition_id)

    _result = if connected?(socket), do: Phoenix.PubSub.subscribe(SM.PubSub, "#{competition.id}-jury")

    socket =
      assign(socket,
        competition: competition,
        user_id: user_id,
        evaluations: competition.allowed_evaluations
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(%{curr_slide: slide_id, image_count: image_count, curr_index: curr_index, jury_pid: jury_pid}, socket) do
    socket =
      case Slides.get(slide_id) do
        {:ok, slide} ->
          can_vote_slide = Jurors.can_vote_slide?(socket.assigns.user_id, slide_id)

          assign(socket,
            slide: slide,
            image_count: image_count,
            curr_index: curr_index,
            can_vote_slide: can_vote_slide,
            jury_pid: jury_pid
          )

        {:error, :not_found} ->
          assign(socket, slide: nil)
      end

    if !is_nil(socket.assigns.watchdog_ref) do
      :ok = Process.cancel_timer(socket.assigns.watchdog_ref, info: false)
    end

    socket = assign(socket, watchdog_ref: Process.send_after(self(), :watchdog, @watchdog_seconds * 1000))

    {:noreply, socket}
  end

  def handle_info(:watchdog, socket) do
    socket = assign(socket, slide: nil, image_count: 0, curr_index: 0)
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
