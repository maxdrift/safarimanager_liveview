defmodule SM.DefaultPasswordTest do
  use ExUnit.Case, async: true

  alias SM.DefaultPassword

  describe "generate/0" do
    test "returns a string" do
      assert is_binary(DefaultPassword.generate())
    end

    test "returns a password with at least 12 characters" do
      password = DefaultPassword.generate()
      assert String.length(password) >= 12
    end

    test "generates different passwords on each call" do
      passwords = for _ <- 1..10, do: DefaultPassword.generate()
      unique_passwords = Enum.uniq(passwords)

      assert length(unique_passwords) == 10
    end

    test "contains at least one uppercase letter" do
      password = DefaultPassword.generate()
      assert String.match?(password, ~r/[A-Z]/)
    end

    test "contains at least one lowercase letter" do
      password = DefaultPassword.generate()
      assert String.match?(password, ~r/[a-z]/)
    end

    test "contains at least one number" do
      password = DefaultPassword.generate()
      assert String.match?(password, ~r/[0-9]/)
    end

    test "contains at least one special character" do
      password = DefaultPassword.generate()
      assert String.match?(password, ~r/[!@#$%^&*]/)
    end

    test "consistently generates valid passwords across many iterations" do
      # Generate 100 passwords and verify all meet requirements
      results =
        for _ <- 1..100 do
          password = DefaultPassword.generate()

          %{
            length: String.length(password) >= 12,
            uppercase: String.match?(password, ~r/[A-Z]/),
            lowercase: String.match?(password, ~r/[a-z]/),
            number: String.match?(password, ~r/[0-9]/),
            special: String.match?(password, ~r/[!@#$%^&*]/)
          }
        end

      assert Enum.all?(results, & &1.length), "All passwords should have at least 12 characters"
      assert Enum.all?(results, & &1.uppercase), "All passwords should have uppercase letters"
      assert Enum.all?(results, & &1.lowercase), "All passwords should have lowercase letters"
      assert Enum.all?(results, & &1.number), "All passwords should have numbers"
      assert Enum.all?(results, & &1.special), "All passwords should have special characters"
    end

    test "password contains only printable ASCII characters" do
      password = DefaultPassword.generate()
      # Allow alphanumerics, url-safe base64 chars (-, _), and our special chars
      assert String.match?(password, ~r/^[A-Za-z0-9\-_!@#$%^&*]+$/)
    end
  end
end
