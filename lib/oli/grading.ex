defmodule Oli.Grading do
  @moduledoc """
  Grading is responsible for compiling attempts into usable gradebook representation
  consumable by various tools such as Excel (CSV) or an LMS API.
  """

  @context_url "https://purl.imsglobal.org/spec/lti/claim/context"

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.ResourceAccess
  alias Oli.Grading.GradebookRow
  alias Oli.Grading.GradebookScore
  alias Oli.Lti_1p3.ContextRoles
  alias Oli.Grading.LTI_AGS
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.ResourceType
  import Ecto.Query, warn: false
  alias Oli.Repo


  @doc """
  If grade passback services 2.0 is enabled, sends the current state of a ResourceAccess
  score for the current user to the LMS.

  If sent successfully, returns {:ok, :synced}

  If grade passback not enabled, returns {:ok, :not_synced}

  If error encountered, returns {:error, error}
  """
  def send_score_to_lms(lti_launch_params, %ResourceAccess{} = resource_access, access_token_provider) do

    # First check to see if grade passback is enabled
    if LTI_AGS.grade_passback_enabled?(lti_launch_params) do

      case access_token_provider.() do
        {:ok, access_token} -> send_score(lti_launch_params, resource_access, access_token)
        e -> e
      end

    else
      {:ok, :not_synced}
    end

  end

  def ags_scopes() do
    [
      "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
      "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
      "https://purl.imsglobal.org/spec/lti-ags/scope/score"
    ]
  end

  defp send_score(lti_launch_params, %ResourceAccess{} = resource_access, token) do

    line_items_service_url = LTI_AGS.get_line_items_url(lti_launch_params)

    context_id = Map.get(lti_launch_params, @context_url) |> Map.get("id")
    label = DeliveryResolver.from_resource_id(context_id, resource_access.resource_id).title

    # Next, fetch (and possibly create) the line item associated with this resource
    case LTI_AGS.fetch_or_create_line_item(line_items_service_url, resource_access.resource_id, 1, label, token) do

      # Finally, post the score for this line item
      {:ok, line_item} ->

        case to_score(Map.get(lti_launch_params, "sub"), resource_access)
        |>  LTI_AGS.post_score(line_item, token) do

          {:ok, _} -> {:ok, :synced}

          e -> e

        end


      e -> e |> IO.inspect

    end
  end

  # helper to create an LTI AGS 2.0 compliant score from our launch params and
  # our resource access
  def to_score(sub, %ResourceAccess{} = resource_access) do

    {:ok, dt} = DateTime.now("Etc/UTC")
    timestamp = DateTime.to_iso8601(dt)

    %Oli.Grading.Score{
      timestamp: timestamp,
      scoreGiven: resource_access.score,
      scoreMaximum: resource_access.out_of,
      comment: "",
      activityProgress: "Completed",
      gradingProgress: "FullyGraded",
      userId: sub,
    }

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
          "#{user.given_name} #{user.family_name} (#{user.email})"
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

    # get publication page resources, filtered by graded: true
    graded_pages = fetch_graded_pages(section.context_id)

    # get students enrolled in the section, filter by role: student
    students = fetch_students(section.context_id)

    # create a map of all resource accesses, keyed off resource id
    resource_accesses = fetch_resource_accesses(section.context_id)

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

  def fetch_students(context_id) do
    Sections.list_enrollments(context_id)
      |> Enum.filter(fn e -> ContextRoles.contains_role?(e.context_roles, ContextRoles.get_role(:context_learner)) end)
      |> Enum.map(fn e -> e.user end)
  end

  def fetch_resource_accesses(context_id) do
    Attempts.get_graded_resource_access_for_context(context_id)
      |> Enum.reduce(%{}, fn resource_access, acc ->
        case acc[resource_access.resource_id] do
          nil ->
            Map.put_new(acc, resource_access.resource_id, Map.put_new(%{}, resource_access.user_id, resource_access))
          resource_accesses ->
            Map.put(acc, resource_access.resource_id, Map.put_new(resource_accesses, resource_access.user_id, resource_access))
        end
      end)
  end

  def fetch_graded_pages(context_id) do
    resource_type_id = ResourceType.get_id_by_type("page")

    Repo.all(from s in Section,
      join: p in Publication, on: p.id == s.publication_id,
      join: m in PublishedResource, on: m.publication_id == p.id,
      join: rev in Revision, on: rev.id == m.revision_id,
      where:
        rev.deleted == false and
        rev.graded == true and
        rev.resource_type_id == ^resource_type_id and
        s.context_id == ^context_id,
      select: rev)
  end

end
