defmodule SMWeb.Components.LiveSearchSelect do
  @moduledoc """
  Search select component.
  """
  use SMWeb, :surface_live_component

  alias SM.Organizations
  alias SMWeb.Components.SearchSelect

  # Organizations.list()
  data items, :list, default: []
  data selected_items, :list, default: []
  prop search, :event, required: true
  prop class, :css_class, default: "input"

  @impl Phoenix.LiveView
  def handle_event("search", %{"value" => ""}, socket) do
    {:noreply, assign(socket, :items, Organizations.list())}
  end

  def handle_event("search", %{"value" => value}, socket) do
    items = list_items() -- socket.assigns.items
    items = Enum.filter(items, &(String.downcase(&1.name) =~ String.downcase(value)))
    {:noreply, assign(socket, :items, items)}
  end

  # def handle_event("select_item", %{"item" => item}, socket) do
  #   send(self(), {:item_selected, item})
  #   {:noreply, socket}
  # end

  # @impl Phoenix.LiveView
  # def handle_info({:item_selected, item}, socket) do
  #   socket =
  #     socket
  #     |> assign(:selected_items, Enum.reverse([item | socket.assigns.selected_items]))
  #     |> assign(:items, socket.assigns.items -- [item])

  #   IO.inspect(socket.assigns.selected_items, label: :selected_items)
  #   {:noreply, socket}
  # end

  # Internal

  defp list_items do
    Organizations.list()
  end
end
