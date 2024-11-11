defmodule Oli.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Oli.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Oli.Accounts.register_independent_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def unique_author_email, do: "author#{System.unique_integer()}@example.com"
  def valid_author_password, do: "hello world!"

  def valid_author_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_author_email(),
      password: valid_author_password()
    })
  end

  def author_fixture(attrs \\ %{}) do
    {:ok, author} =
      attrs
      |> valid_author_attributes()
      |> Oli.Accounts.register_author()

    author
  end
end
