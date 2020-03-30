defmodule Oli.TestHelpers do
  alias Oli.Repo
  alias Oli.Accounts.Author
  alias Oli.Course

  def author_fixture(attrs \\ %{}) do
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

    {:ok, author} =
      Author.changeset(%Author{}, params)
      |> Repo.insert()

    author
  end

  def make_n_projects(0, _author), do: []
  def make_n_projects(n, author) do
    1..n
      |> Enum.map(fn _ -> Course.create_project("test project", author) end)
      |> Enum.map(fn {:ok, %{project: project}} -> project end)
  end
end
