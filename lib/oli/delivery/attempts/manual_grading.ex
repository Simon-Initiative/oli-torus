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
    ActivityAttempt,
    PartAttempt
  }

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
            ilike(resource_revision.title, ^"#{options.text_search}") or
            ilike(activity_revision.title, ^"#{options.text_search}")
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
          order_by(query, [_, u, _], {^direction, field(u, ^field)})
      end

    Repo.all(query)
  end

  def evaluate(%Section{slug: section_slug}, activity_attempt, score_feedbacks_map) do

    graded = activity_attempt.graded
    resource_attempt_guid = activity_attempt.resource_attempt_guid

    Oli.Repo.transaction(fn _ ->

      with {:ok, {all_part_attempts, finalized_part_attempts}} <- finalize_part_attempts(activity_attempt, score_feedbacks_map),
        {:ok, activity_attempt} <- Evaluate.rollup_part_attempt_evaluations(activity_attempt.attempt_guid, :normalize),
        {:ok, _} <- to_attempt_guid(finalized_part_attempts) |> Oli.Delivery.Snapshots.queue_or_create_snapshot(section_slug),
        {:ok, _} <- maybe_finalize_resource_attempt(graded, resource_attempt_guid) do
      else
        e -> Repo.rollback(e)
      end

    end)
  end

  defp finalize_part_attempts(activity_attempt, score_feedbacks_map) do
    part_attempts = Core.get_latest_part_attempts(activity_attempt.attempt_guid)


    Enum.filter(part_attempts, fn pa -> pa.grading_approach == :manual and pa.lifecycle_state == :submitted end)
    |> Enum.reduce_while({part_attempts, []}, fn pa, {:ok, {all, updated}} ->
      case Map.get(score_feedbacks_map, pa.attempt_guid) do
        %{score: score, out_of: out_of, feedback: feedback} ->
          case Core.update_part_attempt(pa, %{score: score, out_of: out_of, feedback: %{content: wrap_in_paragraphs(feedback)}}) do
            {:ok, updated_part_attempt} -> {:cont, {:ok, {all, [updated_part_attempt | updated]}}}
            e -> {:halt, e}
          end
        _ -> {:halt, {:error, "scoring feedback not found for attempt #{pa.attempt_guid}"}}
      end
    end)

  end

  defp maybe_finalize_resource_attempt(false, resource_attempt_guid), do: {:ok, resource_attempt_guid}

  defp maybe_finalize_resource_attempt(true, resource_attempt_guid) do
    Oli.Delivery.Attempts.PageLifecycle.Graded.roll_up_activities_to_resource_attempt(resource_attempt_guid)
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
