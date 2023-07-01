defmodule SMWeb.Components.ValidationCheckmark do
  @moduledoc """
  Conditional checkmark icon for validation
  """

  use SMWeb, :surface_component

  prop variant, :atom, values!: [:pass, :fail, :warn]

  def render(assigns) do
    ~F"""
    {#if @variant == :pass}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class={"h-5", "w-5", "mx-auto", "text-success"}
        viewBox="0 0 20 20"
        fill="currentColor"
      >
        <path
          fill-rule="evenodd"
          d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
          clip-rule="evenodd"
        />
      </svg>
    {#elseif @variant == :fail}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class={"h-5", "w-5", "mx-auto", "text-error"}
        viewBox="0 0 20 20"
        fill="currentColor"
      >
        <path
          fill-rule="evenodd"
          d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
          clip-rule="evenodd"
        />
      </svg>
    {#else}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 20 20"
        stroke-width="1.5"
        stroke="currentColor"
        class={"h-5", "w-5", "mx-auto", "text-warning"}
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
        />
      </svg>
    {/if}
    """
  end
end
