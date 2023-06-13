defmodule SMWeb.Components.Grid do
  @moduledoc """
  Grid component
  """
  use SMWeb, :surface_live_component

  alias Surface.Components.Link
  alias Surface.Components.LivePatch

  prop entity_name, :string

  @doc "The list of items to be rendered"
  prop items, :generator, required: true
  prop create_path, :string
  prop export_path, :string
  prop merge_path, :string
  prop infinite_scroll, :boolean, default: false

  data select_all, :boolean, default: false
  data selection, :any, default: MapSet.new()

  @doc "The list of columns defining the Grid"
  slot cols, required: true, generator_prop: :items

  def render(assigns) do
    ~F"""
    <div {=@id}>
      <div class="flex flex-row-reverse my-2 min-h-8">
        <div>
          <LivePatch :if={@create_path} to={@create_path} class="btn btn-sm btn-success">{gettext("Create")}</LivePatch>
          <Link :if={@export_path} to={@export_path} method={:post} class="btn btn-sm btn-outline">
            {gettext("Export to CSV")}
          </Link>
          <button
            :if={@merge_path && MapSet.size(@selection) > 0}
            class="btn btn-sm btn-secondary"
            :on-click="merge-many"
          >{gettext("Merge into")}</button>
          <button :if={@select_all} class="btn btn-sm btn-error" :on-click="delete-all">
            {gettext("Delete all")}
          </button>
          <button
            :if={MapSet.size(@selection) > 0}
            class="btn btn-sm btn-error"
            :on-click="delete-selected"
          >
            {"#{gettext("Delete selected")} (#{MapSet.size(@selection)})"}
          </button>
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
                    class="checkbox checkbox-sm mt-2"
                    checked={@select_all}
                    :on-change={JS.dispatch("smgr:select-all", detail: %{gridId: @id})}
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
                      name={"#{@id}-selection"}
                      class="checkbox checkbox-sm mt-2"
                      value={item.id}
                      :on-change={JS.dispatch("smgr:select-one", detail: %{gridId: @id})}
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
    </div>
    """
  end

  def handle_event("select-one", %{"id" => id, "value" => value}, socket) do
    selection =
      if value do
        MapSet.put(socket.assigns.selection, id)
      else
        MapSet.delete(socket.assigns.selection, id)
      end

    {:noreply, assign(socket, selection: selection, select_all: false)}
  end

  def handle_event("select-many", %{"ids" => ids}, socket) do
    {:noreply, assign(socket, selection: MapSet.new(ids), select_all: false)}
  end

  def handle_event("select-all", %{"value" => value}, socket) do
    {:noreply, assign(socket, selection: MapSet.new(), select_all: value)}
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

  def handle_event("delete-selected", %{}, socket) do
    selection = MapSet.to_list(socket.assigns.selection)

    on_confirm = fn socket ->
      send(self(), {"delete-selected", selection})

      socket
      |> assign(:selection, MapSet.new())
      |> assign(:select_all, false)
    end

    {:noreply,
     confirm(socket, on_confirm,
       title: gettext("Delete records"),
       description:
         Gettext.gettext(
           SMWeb.Gettext,
           "Are you sure you want to delete #{Enum.count(selection)} records?"
         ),
       confirm_text: gettext("Delete"),
       confirm_icon: "trash"
     )}
  end

  def handle_event("delete-all", %{}, socket) do
    on_confirm = fn socket ->
      send(self(), "delete-all")

      socket
      |> assign(:selection, MapSet.new())
      |> assign(:select_all, false)
    end

    {:noreply,
     confirm(socket, on_confirm,
       title: gettext("Delete all records"),
       description:
         Gettext.gettext(
           SMWeb.Gettext,
           "Are you sure you want to delete all records?"
         ),
       confirm_text: gettext("Delete"),
       confirm_icon: "trash"
     )}
  end
end
