defmodule Oli.Grading do
  @moduledoc """
  Grading is responsible for compiling attempts into usable gradebook representation
  consumable by various tools such as Excel (CSV) or an LMS API
  """

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.ResourceAccess
  alias Oli.Publishing
  alias Oli.Grading.GradebookRow
  alias Oli.Grading.GradebookScore
  alias Oli.Delivery.Sections.SectionRoles

  def export_csv() do

  end

  @doc """
  Returns a tuple containing a list of GradebookRow for every enrolled user
  and an ordered list of column labels

  `{[%GradebookRow{user_id: 123, scores: [%GradebookScore{}, ...]}, ...], ["Quiz 1", "Quiz 2"]}`
  """
  def generate_gradebook_for_section(%Section{} = section) do
    # get publication for the section
    publication = Sections.get_section_publication!(section.id)

    # get publication page resources, filtered by graded: true
    graded_pages = Publishing.get_resource_revisions_for_publication(publication)
      |> Map.values
      |> Enum.filter(fn {_resource, revision} -> revision.graded == true end)
      |> Enum.map(fn {_resource, revision} -> revision end)

    # get students enrolled in the section, filter by role: student
    students = Sections.list_enrollments(section.context_id)
      |> Oli.Repo.preload([:user])
      |> Enum.filter(fn e -> e.section_role_id == SectionRoles.get_by_type("student").id end)
      |> Enum.map(fn e -> e.user end)

    # create a map of all resource accesses, keyed off resource id
    resource_accesses = Enum.reduce(graded_pages, %{}, fn revision, acc ->
      user_resource_access_map = Attempts.get_resource_access_for_context(revision.resource_id, section.context_id)
        |> Enum.reduce(%{}, fn resource_access, acc -> Map.put(acc, resource_access.user_id, resource_access) end)
      Map.put_new acc, revision.resource_id, user_resource_access_map
    end)

    # build gradebook map - for each user in the section, create a gradebook row. Using
    # resource_accesses, create a list of gradebook scores leaving scores null if they do not exist
    gradebook = Enum.map(students, fn %{id: user_id} ->
      scores = Enum.reduce(Enum.reverse(graded_pages), [], fn revision, acc ->
        score = case resource_accesses[revision.resource_id] do
          %{^user_id => student_resource_accesses} ->
            case student_resource_accesses do
              %ResourceAccess{score: score, out_of: out_of} ->
                %GradebookScore{
                  resource_id: revision.resource_id,
                  label: revision.title,
                  score: score,
                  out_of: out_of
                }
              _ -> nil
            end
          _ -> nil
        end

        [score | acc]
      end)

      %GradebookRow{user_id: user_id, scores: scores}
    end)


    # return gradebook
    column_labels = Enum.map graded_pages, fn revision -> revision.title end
    {gradebook, column_labels}
  end
end
