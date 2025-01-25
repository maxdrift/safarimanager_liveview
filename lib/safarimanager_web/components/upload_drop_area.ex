defmodule SMWeb.Components.UploadDropArea do
  @moduledoc """
  Upload drop area component.
  """
  use SMWeb, :component

  # alias Surface.Components.Form.FieldContext
  # alias Surface.Components.LiveFileInput

  attr :field, :atom, required: true
  attr :uploads, :map, required: true
  attr :class, :list, default: []

  slot :inner_block

  def upload_drop_area(assigns) do
    ~H"""
    <div
      phx-drop-target={@uploads |> Map.fetch!(@field) |> Map.fetch!(:ref)}
      class={["flex w-full items-center justify-center" | @class]}
    >
      <label class="w-full flex flex-col items-center px-4 py-6 rounded-lg shadow-inner tracking-wide uppercase border-dashed border-2 cursor-pointer hover:text-info hover:border-info">
        <Heroicons.icon name="arrow-up-tray" type="outline" class="h-8 w-8" />
        <span class="mt-2 text-base leading-normal">
          {render_slot(@inner_block) || gettext("Click or drop files in this box")}
        </span>
        <.live_file_input upload={Map.fetch!(@uploads, @field)} class="hidden" />
      </label>
    </div>
    """
  end
end
