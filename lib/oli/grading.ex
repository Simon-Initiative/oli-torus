defmodule Oli.Grading do
  @moduledoc """
  Grading is responsible for compiling attempts into usable gradebook representation
  consumable by various tools such as Excel (CSV) or an LMS API.
  """
  require Logger

  import Ecto.Query, warn: false
  import Oli.Utils, only: [log_error: 2]

  alias Oli.Publishing.{DeliveryResolver, PublishedResource}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections

  alias Oli.Delivery.Sections.{
    EnrollmentBrowseOptions,
    Section,
    SectionResource,
    SectionsProjectsPublications,
    SectionResourceDepot
  }

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Grading.GradebookRow
  alias Oli.Grading.GradebookScore
  alias Oli.Activities.Realizer.Selection
  alias Oli.Analytics.DataTables.DataTable
  alias Lti_1p3.Tool.Services.AGS
  alias Lti_1p3.Tool.Services.AGS.Score
  alias Oli.Resources.Revision
  alias OliWeb.Common.Utils
  alias Oli.Repo
  alias OliWeb.Delivery.Student.Utils, as: StudentUtils
  alias Oli.Delivery.Sections.ProgressScoringSettings
  alias Oli.Resources.ResourceType

  @doc """
  Determines all scored items (both assessments and progress containers) for a section
  in course order, using the efficient SectionResourceDepot.

  Returns a list of maps with item information needed for line item creation.
  """
  def determine_all_scored_items(section) do
    # Get all graded pages
    graded_pages = SectionResourceDepot.graded_pages(section.id)

    # Get progress scoring settings
    progress_settings = get_progress_scoring_settings(section)

    # Get all containers if progress scoring is enabled
    progress_containers =
      if progress_settings.enabled && not Enum.empty?(progress_settings.container_ids) do
        SectionResourceDepot.containers(section.id)
        |> Enum.filter(fn sr -> sr.resource_id in progress_settings.container_ids end)
      else
        []
      end

    # Combine and sort by numbering_index (course order)
    all_items =
      (graded_pages ++ progress_containers)
      |> Enum.sort_by(& &1.numbering_index)

    # Batch fetch all revisions for graded pages in a single DB call
    graded_page_resource_ids =
      all_items
      |> Enum.filter(fn sr ->
        sr.resource_type_id == ResourceType.id_for_page() && sr.graded
      end)
      |> Enum.map(& &1.resource_id)

    # Make a single batch call to get all revisions
    revisions_map =
      if Enum.empty?(graded_page_resource_ids) do
        %{}
      else
        DeliveryResolver.from_resource_id(section.slug, graded_page_resource_ids)
        |> Map.new(&{&1.resource_id, &1})
      end

    # Transform to the format needed for line item creation
    Enum.map(all_items, fn sr ->
      cond do
        # Is this a graded page?
        sr.resource_type_id == ResourceType.id_for_page() && sr.graded ->
          # Get the revision from our pre-fetched map
          revision = Map.get(revisions_map, sr.resource_id)

          %{
            type: :assessment,
            resource_id: sr.resource_id,
            title: sr.title,
            out_of: determine_page_out_of(section.slug, revision),
            numbering_index: sr.numbering_index
          }

        # Is this a progress container?
        sr.resource_type_id == ResourceType.id_for_container() ->
          %{
            type: :progress_container,
            resource_id: sr.resource_id,
            title: sr.title,
            container_id: sr.resource_id,
            hierarchy_type: progress_settings.hierarchy_type,
            out_of: progress_settings.out_of,
            numbering_index: sr.numbering_index
          }

        true ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_progress_scoring_settings(section) do
    case section.progress_scoring_settings do
      nil ->
        %ProgressScoringSettings{}

      settings_map when is_map(settings_map) ->
        struct(ProgressScoringSettings, atomize_keys(settings_map))

      _ ->
        %ProgressScoringSettings{}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        try do
          {String.to_existing_atom(key), value}
        rescue
          ArgumentError -> {key, value}
        end

      {key, value} ->
        {key, value}
    end)
  end

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
    {gradebook, assessments_column_labels} = generate_gradebook_for_section(section)

    column_labels =
      ["Status", "Name", "Email", "LMS ID" | assessments_column_labels]

    Enum.map(gradebook, &build_gradebook_row/1)
    |> sort_data()
    |> DataTable.new()
    |> DataTable.headers(column_labels)
    |> DataTable.to_csv_content()
  end

  defp build_gradebook_row(%{user: user} = row) do
    main_attrs = %{
      "Status" => StudentUtils.parse_enrollment_status(user.enrollment_status),
      "Name" => Utils.name(user),
      "Email" => user.email,
      "LMS ID" => user.sub
    }

    Enum.reduce(row.scores, main_attrs, fn score, acc ->
      points_earned_column_label = Oli.Utils.title_case("#{score.label} - Points Earned")
      points_possible_column_label = Oli.Utils.title_case("#{score.label} - Points Possible")
      percentage_column_label = Oli.Utils.title_case("#{score.label} - Percentage")

      acc
      |> Map.put(points_earned_column_label, format_score(score.score))
      |> Map.put(
        points_possible_column_label,
        format_score(score.out_of)
      )
      |> Map.put(
        percentage_column_label,
        StudentUtils.parse_percentage(score.score, score.out_of)
      )
    end)
  end

  def format_score(nil), do: nil

  def format_score(score) when is_number(score), do: StudentUtils.parse_score(score)

  defp sort_data(results) do
    Enum.sort_by(results, &{&1["Status"], String.downcase(&1["Name"]), &1["Email"], &1["LMS ID"]})
  end

  @doc """
  Returns a tuple containing a list of GradebookRow for every enrolled user and an ordered list of column labels.

  `{[%GradebookRow{user: %User{}, scores: [%GradebookScore{}, ...]}, ...], ["Assessment 1 - Points Earned", "Assessment 1 - Points Possible", "Assessment 1 - Percentage"]}`

  """
  def generate_gradebook_for_section(%Section{} = section) do
    # get publication page resources, filtered by graded: true and ordered by numbering index
    graded_pages = SectionResourceDepot.graded_pages(section.id)

    # get students enrolled in the section, filter by role: student
    students =
      Sections.browse_enrollments(
        section,
        %Oli.Repo.Paging{offset: 0, limit: nil},
        %Oli.Repo.Sorting{direction: :desc, field: :name},
        %EnrollmentBrowseOptions{
          text_search: "",
          is_student: true,
          is_instructor: false
        }
      )

    # create a map of all resource accesses, keyed off resource id
    resource_accesses = fetch_resource_accesses(section.id)

    # Build gradebook map - for each user in the section, create a gradebook row. Using
    # resource_accesses, create a list of gradebook scores leaving scores null if they do not exist.
    gradebook =
      students
      |> Enum.reverse()
      |> Enum.reduce([], fn %{id: user_id} = student, acc_rows ->
        scores =
          graded_pages
          |> Enum.reverse()
          |> Enum.reduce([], fn section_resource, acc_scores ->
            score =
              with %{^user_id => student_resource_accesses} <-
                     resource_accesses[section_resource.resource_id],
                   %ResourceAccess{score: score, out_of: out_of, was_late: was_late} <-
                     student_resource_accesses do
                %GradebookScore{
                  resource_id: section_resource.resource_id,
                  label: section_resource.title,
                  score: score,
                  out_of: out_of,
                  was_late: was_late
                }
              else
                _ ->
                  %GradebookScore{
                    resource_id: section_resource.resource_id,
                    label: section_resource.title,
                    score: nil,
                    out_of: nil,
                    was_late: nil
                  }
              end

            [score | acc_scores]
          end)

        [%GradebookRow{user: student, scores: scores} | acc_rows]
      end)

    assessments_column_labels =
      graded_pages
      |> Enum.reverse()
      |> Enum.reduce([], fn section_resource, acc ->
        points_earned_column_label =
          Oli.Utils.title_case("#{section_resource.title} - Points Earned")

        points_possible_column_label =
          Oli.Utils.title_case("#{section_resource.title} - Points Possible")

        percentage_column_label = Oli.Utils.title_case("#{section_resource.title} - Percentage")

        [points_earned_column_label, points_possible_column_label, percentage_column_label | acc]
      end)

    {gradebook, assessments_column_labels}
  end

  @doc """
  Returns a list of GradebookScore for enrolled user in the provided section

  `[%GradebookScore{}, GradebookScore{}, ...]`
  """
  def get_scores_for_section_and_user(section_id, student_id) do
    resource_type_id = Oli.Resources.ResourceType.id_for_page()

    Repo.all(
      from(
        sr in SectionResource,
        join: sec in Section,
        on: sec.id == sr.section_id,
        join: spp in SectionsProjectsPublications,
        on: spp.section_id == sec.id and spp.project_id == sr.project_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id,
        join: rev in Revision,
        on: rev.id == pr.revision_id,
        left_join: ra in ResourceAccess,
        on:
          ra.section_id == ^section_id and ra.resource_id == sr.resource_id and
            ra.user_id == ^student_id,
        where:
          sec.id == ^section_id and
            sr.section_id == ^section_id and
            rev.deleted == false and
            rev.resource_type_id == ^resource_type_id and
            rev.graded == true,
        select: %GradebookScore{
          resource_id: rev.resource_id,
          label: rev.title,
          score: ra.score,
          out_of: ra.out_of,
          was_late: ra.was_late,
          index: sr.numbering_index,
          title: sr.title
        }
      )
    )
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

  def determine_page_out_of(section_slug, %Revision{content: content}) do
    {total_out, activity_ids} =
      Oli.Resources.PageContent.flat_filter(
        content,
        &(&1["type"] == "activity-reference" || &1["type"] == "selection")
      )
      |> Enum.reduce({0, []}, fn e, {total_out_of, activity_ids} ->
        case e["type"] do
          "activity-reference" ->
            {total_out_of, activity_ids ++ [e["activity_id"]]}

          "selection" ->
            case Selection.parse(e) do
              {:ok, %Selection{count: selection_count, points_per_activity: points_per_activity}} ->
                {selection_count * points_per_activity + total_out_of, activity_ids}

              _ ->
                {total_out_of, activity_ids}
            end

          _ ->
            {total_out_of, activity_ids}
        end
      end)

    DeliveryResolver.from_resource_id(
      section_slug,
      activity_ids
    )
    |> Enum.reduce(total_out, fn activity, total_out_of ->
      total_out_of + determine_activity_out_of(activity)
    end)
    |> max(1.0)
  end

  def determine_activity_out_of(%Revision{content: content}) do
    case content["authoring"] do
      nil ->
        1.0

      %{"parts" => parts} ->
        case parts do
          nil ->
            1.0

          p ->
            Enum.reduce(p, 0.0, fn part, total_out_of ->
              total_out_of + determine_responses_max_score(part["responses"])
            end)
        end
    end
  end

  defp determine_responses_max_score(nil), do: 1.0

  defp determine_responses_max_score(responses) do
    Enum.reduce(responses, 0.0, fn response, max_score ->
      case response["score"] do
        nil ->
          max_score

        score ->
          max(max_score, score)
      end
    end)
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
end
