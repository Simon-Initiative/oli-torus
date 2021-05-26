defmodule Oli.Analytics.Datashop.Elements.Dataset do
  @moduledoc """
  <dataset>
    <name>example_course-TxE5btqmuCGYEmPUKfewoX</name>
    <level type="Page">
      <name>one</name>
      <problem tutorFlag="tutor">
        <name>one-part1</name>
      </problem>
    </level>
  </dataset>
  """
  import XmlBuilder
  alias Oli.Repo

  def setup(%{
        dataset_name: dataset_name,
        part_attempt: part_attempt,
        problem_name: problem_name,
        publication: publication,
        revision_map: revision_map
      }) do
    element(:dataset, [
      element(:name, dataset_name),
      create_problem_hierarchy(problem_name, publication, part_attempt, revision_map)
    ])
  end

  defp create_problem_hierarchy(problem_name, publication, part_attempt, revision_map) do
    root_resource = Map.get(revision_map, publication.root_resource_id)

    resource_type = Repo.preload(root_resource, :resource_type).resource_type.type

    context = %{
      target: part_attempt.activity_attempt.resource_attempt.revision.resource_id,
      problem_name: problem_name,
      revision_map: revision_map
    }

    element(:level, %{type: resource_type}, [
      element(:name, root_resource.title),
      dfs(context, root_resource.children)
    ])
  end

  defp dfs(
         %{target: target, problem_name: problem_name, revision_map: revision_map} = context,
         nodes
       ) do
    case nodes do
      [] ->
        nil

      [id | ids] ->
        revision = Map.get(revision_map, id)
        resource_type = Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id)

        case resource_type do
          "container" ->
            element(:level, %{type: "Container"}, [
              element(:name, revision.title),
              dfs(context, revision.children ++ ids)
            ])

          "page" ->
            case id == target do
              true ->
                element(:level, %{type: "Page"}, [
                  element(:name, revision.title),
                  element(
                    :problem,
                    %{tutorFlag: tutor_or_test(revision.graded)},
                    [element(:name, problem_name)]
                  )
                ])

              false ->
                dfs(context, ids)
            end

          _ ->
            dfs(context, ids)
        end
    end
  end

  defp tutor_or_test(graded) do
    case graded do
      true -> "test"
      false -> "tutor"
    end
  end
end
