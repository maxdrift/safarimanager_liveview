defmodule SMWeb.Slides do
  @moduledoc """
  Slides live view
  """
  use SMWeb, :surface_view

  alias Phoenix.LiveView
  alias SM.Accounts
  alias SM.Competitions
  alias SM.Slides
  alias Surface.Components.LiveFileInput
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Submit
  alias Surface.Components.LiveRedirect
  alias Surface.Components.LivePatch

  require Logger

  # data user, :struct

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:user, nil)
      |> assign(:slides, [])
      |> allow_upload(:images,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 150,
        max_file_size: 100_000_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("submit", %{}, socket) do
    IO.inspect("submit")
    assigns = socket.assigns

    uploads_path = Slides.get_uploads_path(assigns.competition_id, assigns.user.id)

    :ok =
      "priv/static"
      |> Path.join(uploads_path)
      |> File.mkdir_p!()

    # uploaded_files =
    LiveView.consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
      uploads_path = Path.join(uploads_path, entry.client_name)
      dest = Path.join("priv/static", uploads_path)
      File.cp!(path, dest)
      {:ok, Routes.static_path(socket, uploads_path) |> IO.inspect(label: :uploaded_file)}
    end)

    # IO.inspect(uploaded_files, label: :uploaded_files)

    Enum.each(socket.assigns.uploads.images.entries, fn entry ->
      {:ok, _slide} =
        Slides.create(%{
          user_id: assigns.user.id,
          competition_id: assigns.competition_id,
          file_name: entry.client_name,
          file_size: entry.client_size,
          file_type: entry.client_type
        })
    end)

    {:noreply, socket}
  end

  def handle_event("delete-slide", %{"id" => slide_id}, socket) do
    {:ok, slide} = Slides.get(slide_id)
    {:ok, _slide} = Slides.delete(slide)

    uploads_path = Slides.get_uploads_path(socket.assigns.competition_id, socket.assigns.user.id)

    ["priv/static", uploads_path, slide.file_name]
    |> Path.join()
    |> File.rm!()

    {:noreply, socket}
  end

  def handle_event(_event_name, _params, socket) do
    # IO.inspect(event_name)
    # IO.inspect(params)
    # IO.inspect(socket.assigns.uploads)

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

  def handle_info({_, [:competition, :updated], _result}, socket) do
    {:ok, competition} = Competitions.get(socket.assigns.competition_id)

    socket =
      socket
      |> assign(:competition, competition)

    {:noreply, socket}
  end

  defp image_path(socket, competition_id, user_id, file_name) do
    uploads_path = Slides.get_uploads_path(competition_id, user_id)

    socket
    |> Routes.static_path(uploads_path)
    |> Path.join(file_name)
  end
end
