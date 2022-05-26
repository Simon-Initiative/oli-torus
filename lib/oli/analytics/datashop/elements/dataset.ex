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
  alias Oli.Publishing.AuthoringResolver
  require Logger

  def setup(
        %{
          dataset_name: dataset_name
        } = context
      ) do
    element(:dataset, [
      element(:name, dataset_name),
      create_problem_hierarchy(context)
    ])
  end

  defp create_problem_hierarchy(
         %{
           part_attempt: part_attempt,
           problem_name: problem_name
         } = context
       ) do
    case assemble_from_hierarchy_path(
           Map.put(
             context,
             :target,
             part_attempt.activity_attempt.resource_attempt.revision.resource_id
           )
         ) do
      [] ->
        # if for some reason the path to the page that contained this activity
        # cannot be located within the hierarchy, we create a top-level <level>
        # node and place the <problem> element
        element(:level, %{type: "Page"}, [
          element(:name, "Unknown page title"),
          element(
            :problem,
            %{tutorFlag: tutor_or_test(false)},
            [element(:name, problem_name)]
          )
        ])

      assembled ->
        assembled
    end
  end

  # Assembles nested xml elements from a pre-calculated path in the hierarchy to the page
  defp assemble_from_hierarchy_path(
         %{
           target: target,
           problem_name: problem_name,
           hierarchy_map: hierarchy_map
         } = context
       ) do
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
        rev = AuthoringResolver.from_resource_id(context.project.slug, target)

        # Deleted pages are removed from the container's children list, so they will not be found
        # in the hierarchy. Create a top-level page node for them.
        if !is_nil(rev) && rev.deleted do
          page_to_element.(rev)
        else
          Logger.error(
            "Datashop - could not find path to resource_id #{target} in project #{context.project.slug}"
          )

          []
        end

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
