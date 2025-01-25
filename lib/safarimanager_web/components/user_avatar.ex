defmodule SMWeb.Components.UserAvatar do
  @moduledoc """
  User avatar component.
  """
  use SMWeb, :component

  attr :user, SM.Accounts.User
  attr :class, :list, default: ["w-full", "h-full"]
  attr :text_class, :list, default: []

  def user_avatar(assigns) do
    ~H"""
    <div
      class={@class ++ ~w(rounded-full flex items-center justify-center bg-blue-300)}
      aria-hidden="true"
    >
      <div class={@text_class ++ ~w(text-gray-100 font-semibold)}>
        {avatar_text(@user)}
      </div>
    </div>
    """
  end

  defp avatar_text(nil), do: "?"

  defp avatar_text(%_{first_name: nil, last_name: nil}), do: "?"

  defp avatar_text(%_{first_name: first_name, last_name: last_name}), do: avatar_text("#{first_name} #{last_name}")

  defp avatar_text(name) do
    name
    |> String.split()
    |> Enum.map(&String.at(&1, 0))
    |> Enum.map(&String.upcase/1)
    |> case do
      [initial] -> initial
      initials -> List.first(initials) <> List.last(initials)
    end
  end
end
