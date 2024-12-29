defmodule SMWeb.Components.UploadDropArea do
  @moduledoc """
  Upload drop area component.
  """
  use SMWeb, :surface_component

  alias Surface.Components.Form.FieldContext
  alias Surface.Components.LiveFileInput

  prop field, :atom, required: true
  prop uploads, :map, required: true
  prop class, :css_class

  slot default

  def render(assigns) do
    ~F"""
    <div
      phx-drop-target={@uploads |> Map.fetch!(@field) |> Map.fetch!(:ref)}
      class={"flex w-full items-center justify-center #{@class}"}
    >
      <FieldContext name={@field}>
        <label class="w-full flex flex-col items-center px-4 py-6 rounded-lg shadow-inner tracking-wide uppercase border-dashed border-2 cursor-pointer hover:text-info hover:border-info">
          <Heroicons.icon name="arrow-up-tray" type="outline" class="h-8 w-8" />
          <#slot>
            <span class="mt-2 text-base leading-normal">
              {gettext("Click or drop files in this box")}
            </span>
          </#slot>
          <LiveFileInput upload={Map.fetch!(@uploads, @field)} class="hidden" />
        </label>
      </FieldContext>
    </div>
    """
  end
end
