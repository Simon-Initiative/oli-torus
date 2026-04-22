defmodule Oli.Test.AttemptBuilder do
  @moduledoc """
  Composable delivery-runtime builder for resource_attempt / activity_attempt /
  part_attempt trees. Peer of `Oli.Test.HierarchyBuilder` and
  `Oli.Test.SectionBuilder` — shares their title-keyed accumulator so tests
  compose all three:

      tree =
        %{}
        |> SectionBuilder.build([{:section, "chem"}, {:user, "stu1"}])
        |> AttemptBuilder.build("chem", "stu1",
          {:resource_attempt, "Page A", [
            {:activity_attempt, "MCQ Screen", [
              {:part_attempt, "hypothesis", response: %{"enabled" => true}}
            ]},
            {:activity_attempt, "Text Screen", [
              {:part_attempt, "__default", response: %{"input" => "Hello"}}
            ]}
          ]}
        )

      # Then access any node by title:
      tree["chem"].section
      tree["Page A"].resource_attempt
      tree["MCQ Screen"].activity

  ## Supported node tuples

  - `{:resource_attempt, revision_title}` — bare resource_attempt (no activities)
  - `{:resource_attempt, revision_title, children}` — with activity_attempt children
  - `{:activity_attempt, revision_title, parts}` — with part_attempt children
  - `{:activity_attempt, revision_title, parts, opts}` — extra activity attrs
  - `{:part_attempt, part_id}` — bare part_attempt
  - `{:part_attempt, part_id, opts}` — with :response, :feedback, :attempt_number, etc.
  """

  import Oli.Factory

  def build(tree, section_key, user_key, resource_attempt_spec) do
    section = fetch!(tree, section_key, :section)
    user = fetch!(tree, user_key, :user)
    apply_resource(resource_attempt_spec, tree, section, user)
  end

  @doc """
  Extends an existing resource_attempt with additional activity_attempt /
  part_attempt children. Useful in tests that share a setup-built
  resource_attempt and want to add per-test activities without rebuilding
  the section/user/resource_attempt chain.
  """
  def add_activities(tree, resource_attempt, activity_specs) when is_list(activity_specs) do
    Enum.reduce(activity_specs, tree, fn spec, acc ->
      apply_activity(spec, acc, resource_attempt)
    end)
  end

  defp apply_resource({:resource_attempt, title}, tree, section, user),
    do: apply_resource({:resource_attempt, title, []}, tree, section, user)

  defp apply_resource({:resource_attempt, title, children}, tree, section, user) do
    page_revision = insert(:revision, title: title)

    resource_access =
      insert(:resource_access,
        user: user,
        section: section,
        resource: page_revision.resource
      )

    resource_attempt =
      insert(:resource_attempt,
        resource_access: resource_access,
        revision: page_revision,
        attempt_guid: Ecto.UUID.generate()
      )

    tree =
      Map.put(tree, title, %{
        revision: page_revision,
        resource_access: resource_access,
        resource_attempt: resource_attempt
      })

    Enum.reduce(children, tree, fn child, acc -> apply_activity(child, acc, resource_attempt) end)
  end

  defp apply_activity({:activity_attempt, title, parts}, tree, resource_attempt),
    do: apply_activity({:activity_attempt, title, parts, []}, tree, resource_attempt)

  defp apply_activity({:activity_attempt, title, parts, opts}, tree, resource_attempt) do
    revision = insert(:revision, title: title)

    activity_attempt_attrs =
      Keyword.merge(
        [
          resource_attempt: resource_attempt,
          revision: revision,
          resource: revision.resource,
          attempt_number: 1
        ],
        opts
      )

    activity_attempt = insert(:activity_attempt, activity_attempt_attrs)

    tree = Map.put(tree, title, %{revision: revision, activity: activity_attempt})

    Enum.reduce(parts, tree, fn part, acc -> apply_part(part, acc, activity_attempt) end)
  end

  defp apply_part({:part_attempt, part_id}, tree, activity_attempt),
    do: apply_part({:part_attempt, part_id, []}, tree, activity_attempt)

  defp apply_part({:part_attempt, part_id, opts}, tree, activity_attempt) do
    attrs =
      Keyword.merge(
        [activity_attempt: activity_attempt, part_id: part_id, attempt_number: 1],
        opts
      )

    insert(:part_attempt, attrs)
    tree
  end

  defp fetch!(tree, key, field) do
    case tree do
      %{^key => %{^field => value}} ->
        value

      _ ->
        raise ArgumentError,
              "AttemptBuilder: tree[#{inspect(key)}].#{field} not found. " <>
                "Run SectionBuilder.build first to create the #{field}."
    end
  end
end
