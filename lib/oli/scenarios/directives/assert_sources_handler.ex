defmodule Oli.Scenarios.Directives.AssertSourcesHandler do
  alias Oli.Delivery.Remix
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.AssertSourcesDirective

  def handle(
        %AssertSourcesDirective{user: user_name, section: section_name, products: expected},
        state
      ) do
    with {:ok, user} <- fetch(state.users, user_name, "user"),
         {:ok, section} <- fetch(state.sections, section_name, "section"),
         {:ok, remix_state} <- Remix.init(section, Repo.preload(user, :author)) do
      actual =
        remix_state.available_sources
        |> Enum.filter(&(&1.type == :product))
        |> Enum.map(& &1.title)
        |> Enum.sort()

      expected = Enum.sort(expected)

      verification = %{
        to: section_name,
        passed: actual == expected,
        message: "expected product sources #{inspect(expected)}, got #{inspect(actual)}",
        expected: expected,
        actual: actual
      }

      {:ok, state, verification}
    end
  end

  defp fetch(map, name, type) do
    case Map.fetch(map, name) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "Unknown #{type} '#{name}'"}
    end
  end
end
