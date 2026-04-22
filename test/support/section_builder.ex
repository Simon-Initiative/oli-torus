defmodule Oli.Test.SectionBuilder do
  @moduledoc """
  Composable delivery-side builder for sections and users. Peer of
  `Oli.Test.HierarchyBuilder` — shares its title-keyed tree accumulator so
  tests can chain builders:

      tree =
        build_hierarchy(project, publication, author, {:container, "Root", [...]})
        |> SectionBuilder.build([
          {:section, "chem"},
          {:user, "student1"}
        ])
        |> AttemptBuilder.build("chem", "student1", {:resource_attempt, "Root"})

  Standalone use (no authoring hierarchy) is fine — just start with `%{}`.

  ## Supported node tuples

  - `{:section, key}` — inserts a section, stores under `tree[key].section`
  - `{:section, key, opts}` — same, with extra attrs forwarded to the factory
  - `{:user, key}` — inserts a user, stores under `tree[key].user`
  - `{:user, key, opts}` — same, with extra attrs forwarded to the factory
  """

  import Oli.Factory

  def build(tree \\ %{}, specs) when is_list(specs) do
    Enum.reduce(specs, tree, &apply_node/2)
  end

  defp apply_node({:section, key}, tree), do: apply_node({:section, key, []}, tree)

  defp apply_node({:section, key, opts}, tree) do
    section = insert(:section, opts)
    Map.put(tree, key, Map.merge(Map.get(tree, key, %{}), %{section: section}))
  end

  defp apply_node({:user, key}, tree), do: apply_node({:user, key, []}, tree)

  defp apply_node({:user, key, opts}, tree) do
    user = insert(:user, opts)
    Map.put(tree, key, Map.merge(Map.get(tree, key, %{}), %{user: user}))
  end
end
