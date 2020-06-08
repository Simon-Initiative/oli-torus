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
  alias Oli.Grading.CanvasApi
  alias Oli.Delivery.Sections.SectionRoles

  @doc """
  Sync all scores from the gradebook with LMS

  This function currently uses the Canvas API and only supports canvas. This will later
  be replaced with an LTI 1.3 GS implementation
  """
  def sync_grades(%Section{} = section, opts \\ []) do
    {gradebook, _labels} = generate_gradebook_for_section(section)

    gradebook_columns = gradebook
      |> Enum.reduce(%{}, fn row, acc ->
        Enum.reduce(row.scores, acc, fn score, acc ->
          case score do
            nil -> acc
            score ->
              Map.put_new(acc, "#{score.resource_id}", %{
                label: score.label,
                resource_id: score.resource_id,
                out_of: score.out_of,
              })
          end
        end)
      end)

    # delete all assignments if option is specified
    if Keyword.has_key?(opts, :delete_all_assignments) do
      CanvasApi.get_assignments(section)
      |> Enum.each(fn assignment -> CanvasApi.delete_assignment(section, assignment["id"]) end)
    end

    # get current canvas assignments
    assignments = CanvasApi.get_assignments(section)
    current_columns_map = assignments
      |> Enum.filter(fn assignment -> is_torus?(assignment) end)
      |> Enum.reduce(%{}, fn assignment, acc ->
        Map.put(acc, get_torus(assignment), %{
          label: assignment["name"],
          resource_id: get_torus(assignment),
          out_of: assignment["points_possible"],
        })
      end)

    # determine what columns need to be created from what already exist
    columns_to_create = gradebook_columns
      |> Enum.filter(fn {id, _} -> !Map.has_key?(current_columns_map, id) end)

    # create columns
    columns_to_create
      |> Enum.each(fn {_id, r} -> CanvasApi.create_assignment(section, %{
        "external_tool_tag_attributes" => %{ "url" => "https://torus/#{r.resource_id}"},
        "name" => r.label,
        "submission_types" => [
          "external_tool"
        ],
        "points_possible" => r.out_of,
        "grading_type" => "points",
        "published" => "true"
      }) end)

    # get all assignments including new created columns,
    # create a map from resource id to assignment
    assignments_by_resource_id = CanvasApi.get_assignments(section)
    |> Enum.filter(fn assignment -> is_torus?(assignment) end)
    |> Enum.reduce(%{}, fn assignment, acc ->
      Map.put(acc, get_torus(assignment), assignment)
    end)

    # submit grades
    gradebook
      |> Enum.each(fn row ->
        Enum.each(row.scores, fn score ->
          case score do
            nil -> nil
            score ->
              assignment_id = assignments_by_resource_id["#{score.resource_id}"]["id"]
              user_id = row.user.canvas_id
              CanvasApi.submit_score(section, assignment_id, user_id, score.score)
          end
        end)
      end)
  end

  defp is_torus?(assignment) do
    case assignment["external_tool_tag_attributes"] do
      %{"url" => url} -> String.contains?(url, "torus")
      _ -> false
    end
  end

  defp get_torus(assignment) do
    case assignment["external_tool_tag_attributes"] do
      %{"url" => "https://torus/" <> id} -> id
      _ -> nil
    end
  end

  @doc """
  Exports the gradebook for the provided section in CSV format

  Returns a Stream which can be written to a file or other IO
  """
  def export_csv(%Section{} = section) do
    {gradebook, column_labels} = generate_gradebook_for_section(section)

    table_data = gradebook
      |> Enum.map(fn %GradebookRow{user: user, scores: scores} ->
        [
          "#{user.first_name} #{user.last_name} (#{user.email})"
          | Enum.map(scores, fn gradebook_score ->
            case gradebook_score do
              nil -> nil
              %GradebookScore{score: score} ->
                score
            end
          end)
        ]
      end)

    # unfortunately we must go through every score to ensure out_of has been found for a column
    # TODO: optimize this logic to bail out once an out_of has been discovered for every column
    points_possible = gradebook
      |> Enum.reduce([], fn %GradebookRow{scores: scores}, acc ->
        scores
        |> Enum.with_index
        |> Enum.map(fn {gradebook_score, i} ->
          case gradebook_score do
            nil ->
              # use existing value for column
              Enum.at(acc, i)
            %GradebookScore{out_of: nil} ->
              # use existing value for column
              Enum.at(acc, i)
            %GradebookScore{out_of: out_of} ->
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
    resource_accesses = Attempts.get_graded_resource_access_for_context(section.context_id)
      |> Enum.reduce(%{}, fn resource_access, acc ->
        case acc[resource_access.resource_id] do
          nil ->
            Map.put_new(acc, resource_access.resource_id, Map.put_new(%{}, resource_access.user_id, resource_access))
          resource_accesses ->
            Map.put(acc, resource_access.resource_id, Map.put_new(resource_accesses, resource_access.user_id, resource_access))
        end
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
