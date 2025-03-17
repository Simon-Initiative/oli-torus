defmodule Oli.Delivery.Attempts.ManualGrading do
  import Ecto.Query, warn: false

  @moduledoc """
  Manual activity grading.
  """

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias Oli.Resources.Revision
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  def has_submitted_attempts(%Section{id: section_id}) do
    query =
      ActivityAttempt
      |> join(:left, [aa], resource_attempt in ResourceAttempt,
        on: aa.resource_attempt_id == resource_attempt.id
      )
      |> join(:left, [_, resource_attempt], ra in ResourceAccess,
        on: resource_attempt.resource_access_id == ra.id
      )
      |> where(
        [aa, _resource_attempt, resource_access],
        resource_access.section_id == ^section_id and aa.lifecycle_state == :submitted
      )

    Repo.exists?(query)
  end

  @doc """
  Browsing-based query support for activity attempts that require manual grading.
  """
  def browse_submitted_attempts(
        %Section{id: section_id},
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %BrowseOptions{} = options
      ) do
    filter_by_user =
      if is_nil(options.user_id) do
        true
      else
        dynamic(
          [
            _aa,
            _resource_attempt,
            _resource_access,
            user,
            _activity_revision,
            _resource_revision
          ],
          user.id == ^options.user_id
        )
      end

    filter_by_graded =
      if is_nil(options.graded) do
        true
      else
        dynamic(
          [
            _aa,
            _resource_attempt,
            _resource_access,
            _user,
            _activity_revision,
            resource_revision
          ],
          resource_revision.graded == ^options.graded
        )
      end

    filter_by_activity =
      if is_nil(options.activity_id) do
        true
      else
        dynamic(
          [
            _aa,
            _resource_attempt,
            _resource_access,
            _user,
            activity_revision,
            _resource_revision
          ],
          activity_revision.resource_id == ^options.activity_id
        )
      end

    filter_by_page =
      if is_nil(options.page_id) do
        true
      else
        dynamic(
          [
            _aa,
            _resource_attempt,
            resource_access,
            _user,
            _activity_revision,
            _resource_revision
          ],
          resource_access.resource_id == ^options.page_id
        )
      end

    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        dynamic(
          [_aa, _resource_attempt, _resource_access, user, activity_revision, resource_revision],
          ilike(user.name, ^"%#{options.text_search}%") or
            ilike(user.email, ^"%#{options.text_search}%") or
            ilike(user.given_name, ^"%#{options.text_search}%") or
            ilike(user.family_name, ^"%#{options.text_search}%") or
            ilike(user.name, ^"#{options.text_search}") or
            ilike(user.email, ^"#{options.text_search}") or
            ilike(user.given_name, ^"#{options.text_search}") or
            ilike(user.family_name, ^"#{options.text_search}") or
            ilike(resource_revision.title, ^"%#{options.text_search}%") or
            ilike(activity_revision.title, ^"%#{options.text_search}%")
        )
      end

    query =
      ActivityAttempt
      |> join(:left, [aa], resource_attempt in ResourceAttempt,
        on: aa.resource_attempt_id == resource_attempt.id
      )
      |> join(:left, [_, resource_attempt], ra in ResourceAccess,
        on: resource_attempt.resource_access_id == ra.id
      )
      |> join(:left, [_, _, ra], a in assoc(ra, :user))
      |> join(:left, [aa, _, _, _], activity_revision in Revision,
        on: activity_revision.id == aa.revision_id
      )
      |> join(:left, [_, resource_attempt, _, _, _], resource_revision in Revision,
        on: resource_revision.id == resource_attempt.revision_id
      )
      |> where(^filter_by_user)
      |> where(^filter_by_activity)
      |> where(^filter_by_page)
      |> where(^filter_by_graded)
      |> where(^filter_by_text)
      |> where(
        [aa, _resource_attempt, resource_access, _u, _activity_revision, _resource_revision],
        resource_access.section_id == ^section_id and aa.lifecycle_state == :submitted
      )
      |> limit(^limit)
      |> offset(^offset)
      |> select([aa, _, _, _, _, _], aa)
      |> select_merge(
        [aa, resource_attempt, resource_access, user, activity_revision, resource_revision],
        %{
          total_count: fragment("count(*) OVER()"),
          activity_type_id: activity_revision.activity_type_id,
          activity_title: activity_revision.title,
          page_title: resource_revision.title,
          page_id: resource_revision.resource_id,
          resource_attempt_number: resource_attempt.attempt_number,
          graded: resource_revision.graded,
          user: user,
          revision: activity_revision,
          resource_attempt_guid: resource_attempt.attempt_guid,
          resource_access_id: resource_access.id
        }
      )

    query =
      case field do
        :activity_type_id ->
          order_by(
            query,
            [_aa, _resource_attempt, _resource_access, _u, activity_revision, _resource_revision],
            {^direction, activity_revision.activity_type_id}
          )

        :activity_title ->
          order_by(
            query,
            [_aa, _resource_attempt, _resource_access, _u, activity_revision, _resource_revision],
            {^direction, activity_revision.title}
          )

        :page_title ->
          order_by(
            query,
            [_aa, _resource_attempt, _resource_access, _u, _activity_revision, resource_revision],
            {^direction, resource_revision.title}
          )

        :resource_attempt_number ->
          order_by(
            query,
            [_aa, resource_attempt, _resource_access, _u, _activity_revision, _resource_revision],
            {^direction, resource_attempt.attempt_number}
          )

        :graded ->
          order_by(
            query,
            [_aa, _resource_attempt, _resource_access, _u, _activity_revision, resource_revision],
            {^direction, resource_revision.graded}
          )

        :user ->
          order_by(
            query,
            [_aa, _resource_attempt, _resource_access, u, _activity_revision, resource_revision],
            {^direction, u.family_name}
          )

        _ ->
          order_by(query, [aa, _, _, _, _, _], {^direction, field(aa, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Applies a collection of manual scores and feedbacks to the part attempts of a given activity attempt.

  The activity attempt is assumed to be fully populated with virtual attributes delivered from the
  `browse_submitted_attempts` query from this module.

  The `score_feedbacks_map` is a map of part attempt guids to `ScoreFeedback` structs that contain the
  instructor score, feedback, and the out_of value.

  If this activity is the last activity remaining in a graded page, this will finalize that graded page attempt,
  recalculate a resource access level score, and trigger LMS grade passback (if this is an LMS section and that
  section has gradepassback enabled)
  """
  def apply_manual_scoring(
        %Section{slug: section_slug} = section,
        activity_attempt,
        score_feedbacks_map
      ) do
    graded = activity_attempt.graded
    resource_attempt_guid = activity_attempt.resource_attempt_guid

    part_attempts = Core.get_latest_part_attempts(activity_attempt.attempt_guid)
    datashop_session_id = hd(part_attempts).datashop_session_id

    client_evaluations = Enum.filter(part_attempts, fn pa -> pa.grading_approach == :manual and pa.lifecycle_state == :submitted end)
    |> Enum.map(fn pa ->
      case Map.get(score_feedbacks_map, pa.attempt_guid) do
        %{score: score, out_of: out_of, feedback: feedback} ->
          %Oli.Delivery.Attempts.Core.ClientEvaluation{
            input: pa.input,
            feedback: %{content: wrap_in_paragraphs(feedback)},
            score: score,
            out_of: out_of
          }
        _ ->
          nil
      end
    end)
    |> Enum.filter(fn client_eval -> client_eval != nil end)

    Oli.Delivery.Attempts.ActivityLifecycle.Evaluate.apply_client_evaluation(
      section_slug,
      activity_attempt.attempt_guid,
      client_evaluations,
      datashop_session_id
    )

  end

  defp to_attempt_guid(part_attempts) do
    Enum.map(part_attempts, fn pa -> pa.attempt_guid end)
  end

  defp wrap_in_paragraphs(text) do
    String.split(text, "\n")
    |> Enum.map(fn text ->
      %{type: "p", children: [%{text: text}]}
    end)
  end

end
