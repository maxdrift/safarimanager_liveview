defmodule SM.DefaultPassword do
  @moduledoc """
  Default (random) password generator using native Elixir crypto
  """

  @min_length 12

  @doc """
  Generates a secure random password with a minimum of 12 characters.
  Uses a mix of uppercase, lowercase, numbers, and special characters.
  """
  @spec generate() :: String.t()
  def generate do
    # Generate a password of at least 12 characters
    length = max(@min_length, 12)

    # Use crypto strong random bytes
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> String.slice(0, length)
    |> ensure_character_variety()
  end

  # Ensure the password has variety in character types
  defp ensure_character_variety(password) do
    # If the password doesn't have enough variety, add some guaranteed characters
    if has_sufficient_variety?(password) do
      password
    else
      # Add one of each required character type
      base_password = String.slice(password, 0, @min_length - 4)
      uppercase = String.at("ABCDEFGHIJKLMNOPQRSTUVWXYZ", :rand.uniform(26) - 1)
      lowercase = String.at("abcdefghijklmnopqrstuvwxyz", :rand.uniform(26) - 1)
      number = String.at("0123456789", :rand.uniform(10) - 1)
      special = String.at("!@#$%^&*", :rand.uniform(8) - 1)

      (base_password <> uppercase <> lowercase <> number <> special)
      |> String.graphemes()
      |> Enum.shuffle()
      |> Enum.join()
    end
  end

  defp has_sufficient_variety?(password) do
    has_uppercase = String.match?(password, ~r/[A-Z]/)
    has_lowercase = String.match?(password, ~r/[a-z]/)
    has_number = String.match?(password, ~r/[0-9]/)
    has_special = String.match?(password, ~r/[!@#$%^&*]/)

    has_uppercase and has_lowercase and has_number and has_special
  end
end
