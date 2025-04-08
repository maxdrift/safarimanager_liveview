defmodule SMWeb.Components.Grid do
  @moduledoc """
  Grid component
  """
  use SMWeb, :live_component

  attr :entity_name, :string

  attr :items, :list, required: true
  attr :create_path, :string
  attr :export_path, :string
  attr :merge_path, :string, default: nil
  attr :infinite_scroll, :boolean, default: false
  attr :id_fields, :list, default: [:id]

  slot :col, required: true do
    attr :title, :string
    attr :class, :string
  end

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.form
        id={"#{@id}-grid-form"}
        for={%{}}
        as={:grid_form}
        phx-change="grid-selection-change"
        phx-submit="grid-selection-submit"
        phx-target={@myself}
      >
        <div class="flex flex-row-reverse my-2 min-h-8">
          <div>
            <.link :if={@create_path} patch={@create_path} class="btn btn-sm btn-success">
              {gettext("Create")}
            </.link>
            <.link :if={@export_path} href={@export_path} method="post" class="btn btn-sm btn-outline">
              {gettext("Export to CSV")}
            </.link>
            <button
              :if={@merge_path}
              type="submit"
              name={"#{@id}-selection-merge"}
              class="btn btn-sm btn-secondary"
              phx-click={JS.set_attribute({"value", "merge"}, to: "##{@id}-selection-action-field")}
              disabled
            >
              {gettext("Merge into")}
            </button>
            <button
              type="submit"
              class="btn btn-sm btn-error"
              disabled="true"
              name={"#{@id}-selection-delete"}
            >
              {gettext("Delete")}
            </button>
          </div>
        </div>
        <div class="max-h-full overflow-y-auto tiny-scrollbar">
          <table
            id={"#{@id}-table"}
            class="table table-zebra table-sm table-fixed w-full"
            phx-hook="GridSelection"
          >
            <thead>
              <tr>
                <th class={["sticky", "top-0", "w-1"]}>
                  <label>
                    <input
                      id={"#{@id}-select-all"}
                      type="checkbox"
                      name={"#{@id}-select-all"}
                      class="checkbox checkbox-sm mt-2"
                    />
                  </label>
                </th>
                <th :for={col <- @col} class={["sticky", "top-0", "w-auto", Map.get(col, :class)]}>
                  {col.title}
                </th>
              </tr>
            </thead>
            <tbody id={"#{@id}-table-body"} phx-update="stream">
              <tr :for={{dom_id, item} <- @items} id={dom_id}>
                <td>
                  <label>
                    <input
                      type="checkbox"
                      name={"#{@id}-selection[]"}
                      value={maybe_encode_compound_ids(item, @id_fields)}
                      class="checkbox checkbox-sm mt-2"
                    />
                  </label>
                </td>
                <td :for={col <- @col} class="truncate">
                  {render_slot(col, item)}
                </td>
              </tr>
            </tbody>
          </table>
          <div :if={@infinite_scroll} id="infinite-scroll-marker" phx-hook="InfiniteScroll" />
        </div>
        <.hidden_input id={"#{@id}-selection-action-field"} name={:action} value={:delete} />
      </.form>
    </div>
    """
  end

  def handle_event("grid-selection-change", params, socket) do
    grid_id = socket.assigns.id

    select_all_target = "#{grid_id}-select-all"
    selection_target = "#{grid_id}-selection"

    socket =
      case params["_target"] do
        [^select_all_target] ->
          select_all = Map.get(params, "#{grid_id}-select-all", false) && true

          push_event(socket, "smgr:select-all", %{gridId: grid_id, value: select_all})

        [^selection_target] ->
          push_event(socket, "smgr:select-some", %{gridId: grid_id})
      end

    {:noreply, socket}
  end

  def handle_event("grid-selection-submit", %{"action" => "delete"} = params, socket) do
    grid_id = socket.assigns.id

    select_all = Map.get(params, "#{grid_id}-select-all", false) && true

    selected =
      params
      |> Map.get("#{grid_id}-selection", [])
      |> maybe_decode_compound_ids()

    socket =
      cond do
        select_all ->
          do_delete_all(socket)

        selected != [] ->
          do_delete_some(socket, selected)

        true ->
          socket
      end

    {:noreply, push_event(socket, "smgr:reset-selection", %{gridId: grid_id})}
  end

  def handle_event("grid-selection-submit", %{"action" => "merge"} = params, socket) do
    grid_id = socket.assigns.id

    selected =
      params
      |> Map.get("#{grid_id}-selection", [])
      |> maybe_decode_compound_ids()

    _result = send(self(), {"merge-selected", selected})

    {:noreply, push_event(socket, "smgr:reset-selection", %{gridId: grid_id})}
  end

  def handle_event("delete-one", %{"id" => id}, socket) do
    [id] = maybe_decode_compound_ids([id])

    on_confirm = fn socket ->
      send(self(), {"delete-one", id})

      socket
    end

    {:noreply,
     SMWeb.Components.Confirm.confirm(socket, on_confirm,
       title: gettext("Delete record"),
       description: gettext("Are you sure you want to delete this record?"),
       confirm_text: gettext("Delete"),
       confirm_icon: "trash"
     )}
  end

  # Internal

  defp do_delete_all(socket) do
    on_confirm = fn socket ->
      send(self(), "delete-all")

      socket
    end

    SMWeb.Components.Confirm.confirm(socket, on_confirm,
      title: gettext("Delete all records"),
      description: gettext("Are you sure you want to delete all records?"),
      confirm_text: gettext("Delete"),
      confirm_icon: "trash"
    )
  end

  defp do_delete_some(socket, [_one_item] = selected) do
    IO.inspect(selected, label: "Deleting selected items")

    on_confirm = fn socket ->
      send(self(), {"delete-selected", selected})

      socket
    end

    SMWeb.Components.Confirm.confirm(socket, on_confirm,
      title: gettext("Delete record"),
      description: gettext("Are you sure you want to delete 1 record?"),
      confirm_text: gettext("Delete"),
      confirm_icon: "trash"
    )
  end

  defp do_delete_some(socket, [_ | _] = selected) do
    on_confirm = fn socket ->
      send(self(), {"delete-selected", selected})

      socket
    end

    SMWeb.Components.Confirm.confirm(socket, on_confirm,
      title: gettext("Delete records"),
      description:
        Gettext.gettext(
          SMWeb.Gettext,
          "Are you sure you want to delete #{Enum.count(selected)} records?"
        ),
      confirm_text: gettext("Delete"),
      confirm_icon: "trash"
    )
  end

  defp maybe_encode_compound_ids(item, [id_field]) do
    Map.fetch!(item, id_field)
  end

  defp maybe_encode_compound_ids(item, id_fields) when is_list(id_fields) do
    Enum.map_join(id_fields, ",", fn id_field -> Map.fetch!(item, id_field) end)
  end

  defp maybe_decode_compound_ids(encoded) do
    Enum.map(encoded, fn encoded_ids ->
      encoded_ids
      |> String.split(",")
      |> case do
        [id] -> id
        [_ | _] = ids -> List.to_tuple(ids)
      end
    end)
  end
end
