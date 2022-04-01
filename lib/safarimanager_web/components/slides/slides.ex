defmodule SMWeb.Slides do
  @moduledoc """
  Slides live view
  """
  use SMWeb, :surface_view

  alias Phoenix.LiveView
  alias SM.Accounts
  alias SM.Competitions
  alias SM.ImageProcessing
  alias SM.Participants
  alias SM.Slides
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Form
  # alias Surface.Components.Form.ErrorTag
  # alias Surface.Components.Form.Field
  alias Surface.Components.Form.FieldContext
  # alias Surface.Components.Form.Label
  # alias Surface.Components.Form.Reset
  # alias Surface.Components.Form.Submit
  alias Surface.Components.LiveFileInput
  alias Surface.Components.LivePatch
  alias Surface.Components.LiveRedirect

  require Logger

  # data user, :struct

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:user, nil)
      |> assign(:participants, [])
      |> assign(:slides, [])
      |> allow_upload(:images,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 150,
        max_file_size: 100_000_000,
        progress: &handle_progress/3,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  # def handle_event("submit", %{}, socket) do
  #   IO.inspect("submit")
  #   assigns = socket.assigns

  #   uploads_path = Slides.get_uploads_path(assigns.competition_id, assigns.user.id)

  #   :ok =
  #     "priv/static"
  #     |> Path.join(uploads_path)
  #     |> File.mkdir_p!()

  #   # uploaded_files =
  #   LiveView.consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
  #     uploads_path = Path.join(uploads_path, entry.client_name)
  #     dest = Path.join("priv/static", uploads_path)
  #     File.cp!(path, dest)
  #     {:ok, Routes.static_path(socket, uploads_path)}
  #   end)

  #   # IO.inspect(uploaded_files, label: :uploaded_files)

  #   Enum.each(socket.assigns.uploads.images.entries, fn entry ->
  #     {:ok, _slide} =
  #       Slides.create(%{
  #         user_id: assigns.user.id,
  #         competition_id: assigns.competition_id,
  #         file_name: entry.client_name,
  #         file_size: entry.client_size,
  #         file_type: entry.client_type
  #       })
  #   end)

  #   {:noreply, socket}
  # end

  def handle_event("delete-slide", %{"id" => slide_id}, socket) do
    {:ok, slide} = Slides.get(slide_id)
    {:ok, _slide} = Slides.delete(slide)

    uploads_path = Slides.get_uploads_path(socket.assigns.competition_id, socket.assigns.user.id)

    ["priv/static", uploads_path, slide.file_name]
    |> Path.join()
    |> File.rm()

    ["priv/static", uploads_path, "thumbnails", "100x100", slide.file_name]
    |> Path.join()
    |> File.rm()

    {:noreply, socket}
  end

  def handle_event("delete-all-slides", %{}, socket) do
    for slide <- socket.assigns.slides do
      {:ok, slide} = Slides.get(slide.id)
      {:ok, _slide} = Slides.delete(slide)

      uploads_path =
        Slides.get_uploads_path(socket.assigns.competition_id, socket.assigns.user.id)

      ["priv/static", uploads_path, slide.file_name]
      |> Path.join()
      |> File.rm()

      ["priv/static", uploads_path, "thumbnails", "100x100", slide.file_name]
      |> Path.join()
      |> File.rm()
    end

    {:noreply, socket}
  end

  def handle_event("filter-participants", %{"value" => ""}, socket) do
    participants = Participants.list(socket.assigns.competition_id)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("filter-participants", %{"value" => value}, socket) do
    participants = Participants.list(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event(event_name, params, socket) do
    IO.inspect(event_name, label: __MODULE__)
    IO.inspect(params)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView

  def handle_params(%{"competition_id" => competition_id} = params, _uri, socket) do
    if connected?(socket),
      do: {Competitions.subscribe(), Accounts.subscribe(), Slides.subscribe()}

    user_id = params["user_id"]

    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:participants, Participants.list(competition_id))
      # FIXME: this way of selecting the user forces a re-query of Competition
      |> assign(:user, user_id && Accounts.get_user!(user_id))
      |> assign(:slides, user_id && Slides.list(user_id, competition_id))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _], _result}, socket) do
    user_id = socket.assigns.user.id
    competition_id = socket.assigns.competition_id

    socket = assign(socket, :slides, user_id && Slides.list(user_id, competition_id))

    {:noreply, socket}
  end

  def handle_info({_context, [:competition, :updated], _result}, socket) do
    {:ok, competition} = Competitions.get(socket.assigns.competition_id)
    participants = Participants.list(socket.assigns.competition_id)

    socket =
      socket
      |> assign(:competition, competition)
      |> assign(:participants, participants)

    {:noreply, socket}
  end

  # Internal

  defp handle_progress(:images, entry, socket) do
    # IO.inspect(entry, label: __MODULE__)
    # SongEntryComponent.send_progress(entry)

    if entry.done? do
      IO.inspect("#{entry.ref} complete!", label: __MODULE__)
      process_uploaded_image(socket, entry)
      # async_calculate_duration(socket, entry)
    end

    # {:noreply, put_new_changeset(socket, entry)}
    {:noreply, socket}
  end

  defp process_uploaded_image(socket, %Phoenix.LiveView.UploadEntry{} = entry) do
    # lv = self()
    assigns = socket.assigns

    uploads_path = Slides.get_uploads_path(assigns.competition_id, assigns.user.id)

    :ok =
      "priv/static"
      |> Path.join(uploads_path)
      |> File.mkdir_p!()

    LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
      # TODO: Move this to Context
      uploads_path = Path.join(uploads_path, entry.client_name)
      dest = Path.join("priv/static", uploads_path)
      File.cp!(path, dest)

      {:ok, _slide} =
        Slides.create(%{
          user_id: assigns.user.id,
          competition_id: assigns.competition_id,
          file_name: entry.client_name,
          file_size: entry.client_size,
          file_type: entry.client_type
        })

      Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
        %{height: height, width: width, format: format} = ImageProcessing.get_info(dest)
        IO.inspect("running task for image #{entry.client_name}:", label: __MODULE__)
        IO.inspect(%{height: height, width: width, format: format}, label: __MODULE__)

        thumbs_path =
          dest
          |> Path.dirname()
          |> Path.join("thumbnails")
          |> Path.join("100x100")

        File.mkdir_p!(thumbs_path)

        %{} =
          ImageProcessing.save_thumbnail(
            dest,
            100,
            100,
            Path.join(thumbs_path, entry.client_name)
          )
      end)

      {:ok, Routes.static_path(socket, uploads_path)}
      # Task.Supervisor.start_child(LiveBeats.TaskSupervisor, fn ->
      #   send_update(lv, __MODULE__,
      #     id: socket.assigns.id,
      #     action: {:duration, entry.ref, LiveBeats.MP3Stat.parse(path)}
      #   )
      # end)
    end)
  end

  # defp image_path(socket, competition_id, user_id, file_name) do
  #   uploads_path = Slides.get_uploads_path(competition_id, user_id)

  #   socket
  #   |> Routes.static_path(uploads_path)
  #   |> Path.join(file_name)
  # end

  defp pretty_size(byte_size) do
    cond do
      byte_size >= 1_000_000_000 ->
        byte_size
        |> Decimal.new()
        |> Decimal.div(1_000_000_000)
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("GB")

      byte_size >= 1_000_000 ->
        byte_size
        |> Decimal.new()
        |> Decimal.div(1_000_000)
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("MB")

      byte_size >= 1000 ->
        byte_size
        |> Decimal.new()
        |> Decimal.div(1000)
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("KB")

      true ->
        byte_size
        |> Decimal.new()
        |> Decimal.round(2)
        |> Decimal.to_string(:normal)
        |> Kernel.<>("B")
    end
  end
end
