defmodule Oli.TestHelpers do
  alias Oli.Repo
  alias Oli.Accounts.User

  def user_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        email: "ironman#{System.unique_integer([:positive])}@example.com",
        first_name: "Tony",
        last_name: "Stark",
        token: "2u9dfh7979hfd",
        provider: "google",
        system_role_id: 1,
      })

    {:ok, user} =
      User.changeset(%User{}, params)
      |> Repo.insert()

    user
  end
end
