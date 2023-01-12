defmodule SMWeb.Components.Flash do
  @moduledoc """
  Flash component.
  """
  use SMWeb, :surface_component

  import SMWeb.CoreComponents, only: [show: 1, hide: 2]

  data msg, :string

  @doc "the optional id of flash container"
  prop id, :string, default: "flash"
  @doc "the map of flash messages to display"
  prop flash, :map, default: %{}
  prop title, :string, default: nil
  @doc "used for styling and flash lookup"
  prop kind, :atom, values: [:info, :warning, :error]
  @doc "whether to auto show the flash on mount"
  prop autoshow, :boolean, default: true
  @doc "whether the flash can be closed"
  prop close, :boolean, default: true

  @doc "the optional inner block that renders the flash message"
  slot default

  def render(assigns) do
    assigns = Map.put(assigns, :msg, Phoenix.Flash.get(assigns.flash, assigns.kind))

    ~F"""
    <div
      :if={slot_assigned?(:default) || @msg}
      id={@id}
      phx-mounted={@autoshow && show("##{@id}")}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("#flash")}
      role="alert"
      class={[
        "fixed hidden top-20 right-2 w-80 sm:w-96 z-50 alert shadow-lg",
        @kind == :info && "alert-info",
        @kind == :warning && "alert-warning",
        @kind == :error && "alert-error"
      ]}
    >
      <div>
        <Heroicons.LiveView.icon
          :if={@kind == :info}
          name="information-circle"
          type="outline"
          class="stroke-current flex-shrink-0 h-6 w-6"
        />
        <Heroicons.LiveView.icon
          :if={@kind == :warning}
          name="exclamation-triangle"
          type="outline"
          class="stroke-current flex-shrink-0 h-6 w-6"
        />
        <Heroicons.LiveView.icon
          :if={@kind == :error}
          name="x-circle"
          type="outline"
          class="stroke-current flex-shrink-0 h-6 w-6"
        />
        <div>
          <h3 :if={@title} class="font-bold">{@title}</h3>
          <div class="text-xs">
            <#slot>
              {@msg}
            </#slot>
          </div>
        </div>
      </div>
      <div class="flex-none">
        <button
          :if={@close}
          type="button"
          class="group absolute top-2 right-1 p-2"
          aria-label={gettext("close")}
        >
          <Heroicons.LiveView.icon
            name="x-mark"
            type="solid"
            class="h-5 w-5 stroke-current opacity-40 group-hover:opacity-70"
          />
        </button>
      </div>
    </div>
    """
  end
end
