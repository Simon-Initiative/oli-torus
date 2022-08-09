defmodule Oli.Grading do
  @moduledoc """
  Grading is responsible for compiling attempts into usable gradebook representation
  consumable by various tools such as Excel (CSV) or an LMS API.
  """
  require Logger

  import Ecto.Query, warn: false
  import Oli.Utils, only: [log_error: 2]

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Grading.GradebookRow
  alias Oli.Grading.GradebookScore
  alias Oli.Activities.Realizer.Selection
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.Services.AGS
  alias Lti_1p3.Tool.Services.AGS.Score
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.ResourceType
  alias Oli.Repo
  alias Oli.Delivery.Sections.SectionsProjectsPublications

  @doc """
  If grade passback services 2.0 is enabled, sends the current state of a ResourceAccess
  score for the current user to the LMS.

  If sent successfully, returns {:ok, :synced}

  If grade passback not enabled, returns {:ok, :not_synced}

  If error encountered, returns {:error, error}
  """
  def send_score_to_lms(section, user, %ResourceAccess{} = resource_access, access_token_provider) do
    # First check to see if grade passback is enabled
    if section.grade_passback_enabled do
      case access_token_provider.() do
        {:ok, access_token} -> send_score(section, user, resource_access, access_token)
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
      "https://purl.imsglobal.org/spec/lti-ags/scope/score",
      "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly"
    ]
  end

  defp send_score(section, user, %ResourceAccess{} = resource_access, token) do
    revision = DeliveryResolver.from_resource_id(section.slug, resource_access.resource_id)

    out_of_provider = fn -> determine_page_out_of(section.slug, revision) end

    # Next, fetch (and possibly create) the line item associated with this resource
    case AGS.fetch_or_create_line_item(
           section.line_items_service_url,
           resource_access.resource_id,
           out_of_provider,
           revision.title,
           token
         ) do
      # Finally, post the score for this line item
      {:ok, line_item} ->
        case to_score(user.sub, resource_access)
             |> AGS.post_score(line_item, token) do
          {:ok, _} -> {:ok, :synced}
          e -> e
        end

      {:error, e} ->
        {_id, msg} = log_error("Failed to fetch or create LMS line item", e)

        {:error, msg}
    end
  end

  # helper to create an LTI AGS 2.0 compliant score from our launch params and
  # our resource access
  def to_score(sub, %ResourceAccess{} = resource_access) do
    {:ok, dt} = DateTime.now("Etc/UTC")
    timestamp = DateTime.to_iso8601(dt)

    %Score{
      timestamp: timestamp,
      scoreGiven: resource_access.score,
      scoreMaximum: resource_access.out_of,
      comment: "",
      activityProgress: "Completed",
      gradingProgress: "FullyGraded",
      userId: sub
    }
  end

  @doc """
  Exports the gradebook for the provided section in CSV format

  Returns a Stream which can be written to a file or other IO
  """
  def export_csv(%Section{} = section) do
    {gradebook, column_labels} = generate_gradebook_for_section(section)

    table_data =
      gradebook
      |> Enum.map(fn %GradebookRow{user: user, scores: scores} ->
        [
          "#{user.name} (#{user.email})"
          | Enum.map(scores, fn gradebook_score ->
              case gradebook_score do
                nil ->
                  nil

                %GradebookScore{score: score} ->
                  score
              end
            end)
        ]
      end)

    # unfortunately we must go through every score to ensure out_of has been found for a column
    # TODO: optimize this logic to bail out once an out_of has been discovered for every column
    points_possible =
      gradebook
      |> Enum.reduce([], fn %GradebookRow{scores: scores}, acc ->
        scores
        |> Enum.with_index()
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

    (column_labels ++ points_possible ++ table_data)
    |> CSV.encode()
  end

  @doc """
  Returns a tuple containing a list of GradebookRow for every enrolled user
  and an ordered list of column labels

  `{[%GradebookRow{user: %User{}, scores: [%GradebookScore{}, ...]}, ...], ["Quiz 1", "Quiz 2"]}`
  """
  def generate_gradebook_for_section(%Section{} = section) do
    # get publication page resources, filtered by graded: true
    graded_pages = fetch_graded_pages(section.slug)

    # get students enrolled in the section, filter by role: student
    students = fetch_students(section.slug)

    # create a map of all resource accesses, keyed off resource id
    resource_accesses = fetch_resource_accesses(section.id)

    # build gradebook map - for each user in the section, create a gradebook row. Using
    # resource_accesses, create a list of gradebook scores leaving scores null if they do not exist
    gradebook =
      Enum.map(students, fn %{id: user_id} = student ->
        scores =
          Enum.reduce(Enum.reverse(graded_pages), [], fn revision, acc ->
            score =
              case resource_accesses[revision.resource_id] do
                %{^user_id => student_resource_accesses} ->
                  case student_resource_accesses do
                    %ResourceAccess{score: score, out_of: out_of} ->
                      %GradebookScore{
                        resource_id: revision.resource_id,
                        label: revision.title,
                        score: score,
                        out_of: out_of
                      }

                    _ ->
                      nil
                  end

                _ ->
                  nil
              end

            [score | acc]
          end)

        %GradebookRow{user: student, scores: scores}
      end)

    # return gradebook
    column_labels = Enum.map(graded_pages, fn revision -> revision.title end)

    {gradebook, column_labels}
  end

  @doc """
  Determines the maximum point value that can be obtained for a page.

  Two implementations exist, one for adaptive pages and one for regular pages. The
  adaptive implementation reads the "totalScore" key that should be present under the
  "custom" key.

  The basic implementation counts the activities present (including those from
  activity bank selections).
  """
  def determine_page_out_of(_section_slug, %Revision{
        content: %{"advancedDelivery" => true} = content
      }) do
    read_total_score(content)
    |> ensure_valid_number()
    |> max(1.0)
  end

  def determine_page_out_of(_section_slug, %Revision{content: %{"model" => model}}) do
    Enum.reduce(model, 0, fn e, count ->
      case e["type"] do
        "activity-reference" ->
          count + 1

        "selection" ->
          case Selection.parse(e) do
            {:ok, %Selection{count: selection_count}} -> selection_count + count
            _ -> count
          end

        _ ->
          count
      end
    end)
    |> max(1.0)
  end

  # reads the "custom / totalScore" nested key in a robust manner, with a default
  # value of 1.0.
  defp read_total_score(content) do
    Map.get(content, "custom", %{"totalScore" => 1.0})
    |> Map.get("totalScore", 1.0)
  end

  # ensure the read total score is a number, converting from a string and
  # ignoring other constructs (imagine a JSON object here instead)
  defp ensure_valid_number(value) when is_binary(value) do
    case Float.parse(value) do
      {f, _} -> f
      _ -> 1.0
    end
  end

  defp ensure_valid_number(value) when is_integer(value), do: value
  defp ensure_valid_number(value) when is_float(value), do: value
  defp ensure_valid_number(_), do: 1.0

  def fetch_students(section_slug) do
    Sections.list_enrollments(section_slug)
    |> Enum.filter(fn e ->
      ContextRoles.contains_role?(e.context_roles, ContextRoles.get_role(:context_learner))
    end)
    |> Enum.map(fn e -> e.user end)
  end

  def fetch_instructors(section_slug) do
    Sections.list_enrollments(section_slug)
    |> Enum.filter(fn e ->
      ContextRoles.contains_role?(e.context_roles, ContextRoles.get_role(:context_instructor))
    end)
    |> Enum.map(fn e -> e.user end)
  end

  def fetch_resource_accesses(section_id) do
    Attempts.get_graded_resource_access_for_context(section_id)
    |> Enum.reduce(%{}, fn resource_access, acc ->
      case acc[resource_access.resource_id] do
        nil ->
          Map.put_new(
            acc,
            resource_access.resource_id,
            Map.put_new(%{}, resource_access.user_id, resource_access)
          )

        resource_accesses ->
          Map.put(
            acc,
            resource_access.resource_id,
            Map.put_new(resource_accesses, resource_access.user_id, resource_access)
          )
      end
    end)
  end

  def fetch_graded_pages(section_slug) do
    resource_type_id = ResourceType.get_id_by_type("page")

    Repo.all(
      from(s in Section,
        join: spp in SectionsProjectsPublications,
        on: s.id == spp.section_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id,
        join: rev in Revision,
        on: rev.id == pr.revision_id,
        where:
          rev.deleted == false and
            rev.graded == true and
            rev.resource_type_id == ^resource_type_id and
            s.slug == ^section_slug and
            s.status == :active,
        order_by: [rev.inserted_at, rev.id],
        distinct: true,
        select: rev
      )
    )
  end
end
