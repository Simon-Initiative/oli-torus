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

  @doc """
  Exports the gradebook for the provided section in CVS format

  Returns a Stream which can be written to a file or other IO
  """
  def export_csv(%Section{} = section) do
    {gradebook, column_labels} = generate_gradebook_for_section(section)

    table_data = gradebook
      |> Enum.map(fn %GradebookRow{user: user, scores: scores} ->
        [
          "#{user.first_name} #{user.last_name} (#{user.email})"
          | Enum.map(scores, fn %GradebookScore{score: score} -> score end)
        ]
      end)

    # unfortunately we must go through every score to ensure out_of has been found for a column
    # TODO: optimize this logic to bail out once an out_of has been discovered for every column
    points_possible = gradebook
      |> Enum.reduce([], fn %GradebookRow{scores: scores}, acc ->
        scores
        |> Enum.with_index
        |> Enum.map(fn {%GradebookScore{out_of: out_of}, i} ->
          case out_of do
            nil ->
              # use existing value for column
              Enum.at(acc, i)
            out_of ->
              # replace value of existing column
              out_of
          end
        end)
      end)

    points_possible = [["    Points Possible" | points_possible]]
    column_labels = [["Student" | column_labels]]

    column_labels ++ points_possible ++ table_data
    |> CSV.encode
  end

  @doc """
  Returns a tuple containing a list of GradebookRow for every enrolled user
  and an ordered list of column labels

  `{[%GradebookRow{user: %User{}, scores: [%GradebookScore{}, ...]}, ...], ["Quiz 1", "Quiz 2"]}`
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
    gradebook = Enum.map(students, fn (%{id: user_id} = student) ->
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

      %GradebookRow{user: student, scores: scores}
    end)


    # return gradebook
    column_labels = Enum.map graded_pages, fn revision -> revision.title end
    {gradebook, column_labels}
  end
end
