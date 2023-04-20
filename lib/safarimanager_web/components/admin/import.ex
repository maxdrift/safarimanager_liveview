defmodule SMWeb.Components.Admin.Import do
  @moduledoc """
  Import live view
  """
  use SMWeb, :surface_view

  alias Ecto.Changeset
  alias Phoenix.Component
  alias Phoenix.LiveView
  alias SM.CSVImport
  alias SMWeb.Components.Layout
  alias SMWeb.Components.UploadDropArea
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit

  require Logger

  @form_schema %{table: :string, csv: :string}

  @tables [
    "categories",
    "competitions",
    "evaluations",
    "jurors",
    "organizations",
    "participants",
    "slides",
    "subjects",
    "users"
  ]

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:tables, [
        {gettext("Categories"), "categories"},
        {gettext("Competitions"), "competitions"},
        {gettext("Evaluations"), "evaluations"},
        {gettext("Jurors"), "jurors"},
        {gettext("Organizations"), "organizations"},
        {gettext("Participants"), "participants"},
        {gettext("Slides"), "slides"},
        {gettext("Subjects"), "subjects"},
        {gettext("Users"), "users"}
      ])
      |> assign(:import_changeset, reset_changes())
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        auto_upload: false
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"import" => form_data}, socket) do
    changeset =
      {%{}, @form_schema}
      |> Changeset.cast(form_data, [:table])
      |> Changeset.validate_required([:table])
      |> Changeset.validate_inclusion(:table, @tables)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :import_changeset, changeset)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, LiveView.cancel_upload(socket, :csv, ref)}
  end

  def handle_event("submit", _params, socket) do
    table = Changeset.fetch_field!(socket.assigns.import_changeset, :table)

    # Expect a single entry based on the allow_upload/3 'max_entries' configuration
    [%{success: success, failure: failure}] =
      LiveView.consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        {:ok, CSVImport.import(table, path)}
      end)

    socket =
      socket
      |> assign(:import_changeset, reset_changes())
      |> put_flash(
        :info,
        gettext("Imported %{success} of %{total} entries in %{table}",
          success: success,
          total: success + failure,
          table: Gettext.gettext(SMWeb.Gettext, String.capitalize(table))
        )
      )

    {:noreply, socket}
  end

  def handle_event("clear-form", _params, socket) do
    socket =
      socket.assigns.uploads.csv.entries
      |> Enum.reduce(socket, fn entry, acc ->
        LiveView.cancel_upload(acc, :csv, entry.ref)
      end)

    {:noreply, assign(socket, :import_changeset, reset_changes())}
  end

  defp error_to_string(:too_large), do: gettext("Too large")
  defp error_to_string(:too_many_files), do: gettext("You have selected too many files")
  defp error_to_string(:not_accepted), do: gettext("You have selected an unacceptable file type")

  defp reset_changes do
    Changeset.change({%{}, @form_schema}, %{})
  end
end
