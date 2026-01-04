defmodule SM.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `SM.Accounts` context.
  """

  def unique_user_email, do: unique_user_email(System.unique_integer())
  def unique_user_email(user_id), do: "user-#{user_id}@example.com"

  def unique_user_last_name, do: unique_user_last_name(System.unique_integer())
  def unique_user_last_name(user_id), do: "user #{user_id}"

  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    user_id = System.unique_integer([:positive])

    attrs = if is_list(attrs), do: Map.new(attrs), else: attrs

    Map.merge(
      %{
        email: unique_user_email(user_id),
        password: valid_user_password(),
        last_name: unique_user_last_name(user_id),
        first_name: "test"
      },
      attrs
    )
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> SM.Accounts.register_user()

    user
  end

  def competition_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> SM.Accounts.register_simplified_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
