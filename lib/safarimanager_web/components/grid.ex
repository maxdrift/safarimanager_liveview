defmodule SMWeb.Components.Grid do
  @moduledoc """
  Grid component
  """
  use SMWeb, :surface_live_component

  alias Surface.Components.Form
  alias Surface.Components.Form.Submit
  alias Surface.Components.Link
  alias Surface.Components.LivePatch

  prop entity_name, :string

  @doc "The list of items to be rendered"
  prop items, :generator, required: true
  prop create_path, :string
  prop export_path, :string
  prop merge_path, :string
  prop infinite_scroll, :boolean, default: false

  @doc "The list of columns defining the Grid"
  slot cols, required: true, generator_prop: :items

  def render(assigns) do
    ~F"""
    <div {=@id}>
      <Form
        id={"#{@id}-grid-form"}
        for={%{}}
        as={:grid_form}
        change="grid-selection-change"
        submit="grid-selection-submit"
      >
        <div class="flex flex-row-reverse my-2 min-h-8">
          <div>
            <LivePatch :if={@create_path} to={@create_path} class="btn btn-sm btn-success">{gettext("Create")}</LivePatch>
            <Link :if={@export_path} to={@export_path} method={:post} class="btn btn-sm btn-outline">
              {gettext("Export to CSV")}
            </Link>
            <button
              name={"#{@id}-selection-action"}
              :if={@merge_path}
              class="btn btn-sm btn-secondary"
              :on-click="merge-many"
              disabled
            >{gettext("Merge into")}</button>
            <Submit class="btn btn-sm btn-error" opts={disabled: true, name: "#{@id}-selection-action"}>{gettext("Delete")}</Submit>
          </div>
        </div>
        <div class="max-h-full overflow-y-auto tiny-scrollbar">
          <table id={"#{@id}-table"} class="table table-zebra table-fixed w-full" :hook="GridSelection">
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
                {#for col <- @cols}
                  <th class={["sticky", "top-0", "w-auto" | col.class]}>{col.title}</th>
                {/for}
              </tr>
            </thead>
            <tbody phx-update="stream">
              {#for {dom_id, item} <- @items}
                <tr id={dom_id}>
                  <td>
                    <label>
                      <input
                        type="checkbox"
                        name={"#{@id}-selection[]"}
                        value={item.id}
                        class="checkbox checkbox-sm mt-2"
                      />
                    </label>
                  </td>
                  {#for col <- @cols}
                    <td class="truncate">
                      <#slot {col} generator_value={item} />
                    </td>
                  {/for}
                </tr>
              {/for}
            </tbody>
          </table>
          <div :if={@infinite_scroll} id="infinite-scroll-marker" :hook="InfiniteScroll" />
        </div>
      </Form>
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

  def handle_event("grid-selection-submit", params, socket) do
    grid_id = socket.assigns.id

    select_all = Map.get(params, "#{grid_id}-select-all", false) && true
    selected = Map.get(params, "#{grid_id}-selection", [])

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

  def handle_event("delete-one", %{"id" => id}, socket) do
    on_confirm = fn socket ->
      send(self(), {"delete-one", id})

      socket
      |> assign(:selection, MapSet.new())
      |> assign(:select_all, false)
    end

    {:noreply,
     confirm(socket, on_confirm,
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

    confirm(socket, on_confirm,
      title: gettext("Delete all records"),
      description: gettext("Are you sure you want to delete all records?"),
      confirm_text: gettext("Delete"),
      confirm_icon: "trash"
    )
  end

  defp do_delete_some(socket, [_one_item] = selected) do
    on_confirm = fn socket ->
      send(self(), {"delete-selected", selected})

      socket
    end

    confirm(socket, on_confirm,
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

    confirm(socket, on_confirm,
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
end
