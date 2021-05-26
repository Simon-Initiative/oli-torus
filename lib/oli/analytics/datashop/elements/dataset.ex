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

  def setup(%{
        dataset_name: dataset_name,
        part_attempt: part_attempt,
        problem_name: problem_name,
        revision_map: revision_map,
        hierarchy_map: hierarchy_map
      }) do
    element(:dataset, [
      element(:name, dataset_name),
      create_problem_hierarchy(
        problem_name,
        part_attempt,
        revision_map,
        hierarchy_map
      )
    ])
  end

  defp create_problem_hierarchy(
         problem_name,
         part_attempt,
         revision_map,
         hierarchy_map
       ) do
    context = %{
      target: part_attempt.activity_attempt.resource_attempt.revision.resource_id,
      problem_name: problem_name,
      revision_map: revision_map,
      hierarchy_map: hierarchy_map
    }

    case assemble_from_hierarchy_path(context) do
      [] ->
        # if for some reason the path to the page that contained this activity
        # cannot be located within  the hierarchy, we do a best effort and place
        # just the <problem> element
        element(
          :problem,
          %{tutorFlag: tutor_or_test(false)},
          [element(:name, problem_name)]
        )

      assembled ->
        assembled
    end
  end

  # Assembles nested xml elements from a pre-calculated path in the hierarchy to the page
  defp assemble_from_hierarchy_path(%{
         target: target,
         problem_name: problem_name,
         hierarchy_map: hierarchy_map
       }) do
    page_to_element = fn revision ->
      element(:level, %{type: "Page"}, [
        element(:name, revision.title),
        element(
          :problem,
          %{tutorFlag: tutor_or_test(revision.graded)},
          [element(:name, problem_name)]
        )
      ])
    end

    container_to_element = fn revision, c ->
      element(:level, %{type: "Container"}, [
        element(:name, revision.title),
        c
      ])
    end

    case Map.get(hierarchy_map, target) do
      nil ->
        []

      path ->
        [
          Enum.reduce(path, [], fn e, a ->
            case Oli.Resources.ResourceType.get_type_by_id(e.resource_type_id) do
              "page" -> page_to_element.(e)
              "container" -> container_to_element.(e, a)
            end
          end)
        ]
    end
  end

  defp tutor_or_test(graded) do
    case graded do
      true -> "test"
      false -> "tutor"
    end
  end
end
