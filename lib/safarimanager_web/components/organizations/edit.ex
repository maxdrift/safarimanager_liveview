defmodule SMWeb.Components.Organizations.Edit do
  @moduledoc """
  Organization edit component.
  """
  use Surface.LiveComponent

  require Logger

  alias Phoenix.LiveView.Socket
  alias SM.Organizations
  alias SM.Organizations.Organization
  alias SMWeb.Atoms.Alert
  alias SMWeb.Components.Dialog
  alias Surface.Components.Form
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.Reset

  data show, :boolean, default: false
  data changeset, :changeset, default: Organizations.change(%Organization{})
  data organization, :struct, default: %Organization{}
  data error_message, :string, default: nil
  data action, :atom, values!: [:create, :edit]

  # Public API

  def show(dialog_id, organization_id) do
    case Organizations.get(organization_id) do
      {:ok, organization} ->
        changeset = Organizations.change(organization, %{})

        send_update(__MODULE__,
          id: dialog_id,
          organization: organization,
          changeset: changeset,
          action: :edit,
          show: true
        )

      {:error, reason} = error ->
        Logger.error("Error showing Edit modal: #{inspect(reason)}")
        error
    end
  end

  def show(dialog_id) do
    send_update(__MODULE__, id: dialog_id, action: :create, show: true)
  end

  # Event handlers

  def handle_event("validate", %{"organization" => params}, socket) do
    changeset =
      socket.assigns.organization
      |> Organizations.change(params)
      |> Map.put(:action, :validate)

    socket = assign(socket, :changeset, changeset)
    {:noreply, socket}
  end

  def handle_event(
        "submit",
        %{"organization" => params},
        %Socket{assigns: %{action: :create}} = socket
      ) do
    case Organizations.create(params) do
      {:ok, _organization} ->
        socket =
          socket
          |> assign(show: false)
          |> assign_clean_changeset()
          |> push_patch(to: "/organizations")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event(
        "submit",
        %{"organization" => params},
        %Socket{assigns: %{action: :edit}} = socket
      ) do
    case Organizations.update(socket.assigns.organization, params) do
      {:ok, _organization} ->
        socket =
          socket
          |> assign(show: false)
          |> assign_clean_changeset()
          |> push_patch(to: "/organizations")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("show", _, socket) do
    socket =
      socket
      |> assign(show: true)

    {:noreply, socket}
  end

  def handle_event("hide", _, socket) do
    socket =
      socket
      |> assign(show: false)
      |> assign_clean_changeset()
      |> push_patch(to: "/organizations")

    {:noreply, socket}
  end

  # Internal

  defp assign_clean_changeset(socket) do
    socket
    |> assign(:changeset, Organizations.change(%Organization{}))
  end
end
