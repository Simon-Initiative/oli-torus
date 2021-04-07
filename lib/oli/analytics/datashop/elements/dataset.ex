
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
  alias Oli.Publishing
  alias Oli.Repo

  def setup(%{
    dataset_name: dataset_name,
    part_attempt: part_attempt,
    problem_name: problem_name,
    publication: publication
  }) do
    element(:dataset, [
      element(:name, dataset_name),
      create_problem_hierarchy(problem_name, publication, part_attempt)
    ])
  end

  defp create_problem_hierarchy(problem_name, publication, part_attempt) do
    root_resource = Publishing.get_published_revision(publication.id, publication.root_resource_id)
    resource_type = Repo.preload(root_resource, :resource_type).resource_type.type
    context = %{
      target: part_attempt.activity_attempt.resource_attempt.revision.resource_id,
      problem_name: problem_name,
      publication: publication
    }

    element(:level, %{type: resource_type}, [
      element(:name, root_resource.title),
      dfs(context, root_resource.children)
    ])
  end

  defp dfs(%{target: target, problem_name: problem_name, publication: publication} = context, nodes) do
    case nodes do
      [] -> nil
      [id | ids] ->
        revision = Publishing.get_published_revision(publication.id, id)
        resource_type = Repo.preload(revision, :resource_type).resource_type.type
        case resource_type do
          "container" ->
            element(:level, %{type: "Container"}, dfs(context, [revision.children | nodes]))
          "page" ->
            case id == target do
              true ->
                element(:level, %{type: "Page"}, [
                  element(:name, revision.title),
                  element(:problem,
                    %{tutorFlag: tutor_or_test(revision.graded)},
                    [element(:name, problem_name)])
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
