defmodule Oli.Delivery.Attempts.ManualGrading do
  import Ecto.Query, warn: false

  @moduledoc """
  Manual activity grading.
  """

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Enrollment, Section}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Activities.AdaptiveParts
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias Oli.Delivery.Settings
  alias Oli.Resources.Revision
  alias Oli.Delivery.Attempts.Core

  alias Oli.Delivery.Attempts.ActivityLifecycle.ApplyClientEvaluation
  alias Oli.Delivery.Attempts.ActivityLifecycle.RollUp
  alias Oli.Delivery.Experiments.RewardHandoff

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

  @unfiltered %BrowseOptions{
    user_ids: [],
    activity_ids: [],
    page_ids: [],
    graded: nil,
    text_search: ""
  }

  @doc """
  Browsing-based query support for activity attempts that require manual grading.

  Rows are ordered by the requested sort key and then by attempt id in the same direction, so
  paging and the Previous/Next navigation see the same order for tied rows.
  """
  def browse_submitted_attempts(
        %Section{id: section_id},
        %Paging{limit: limit, offset: offset},
        %Sorting{} = sorting,
        %BrowseOptions{} = options
      ) do
    section_id
    |> submitted_attempts_query(options)
    |> order_by(^order_by_sorting(sorting))
    |> limit(^limit)
    |> offset(^offset)
    |> select_browse_fields()
    |> select_merge([aa], %{total_count: fragment("count(*) OVER()")})
    |> Repo.all()
  end

  @doc """
  Loads one attempt awaiting manual scoring, scoped to the section, with the same fields as the
  rows of `browse_submitted_attempts/4`. Returns `nil` when the attempt is not pending, belongs to
  another section, or does not exist.
  """
  def fetch_submitted_attempt(%Section{id: section_id}, attempt_id) do
    section_id
    |> submitted_attempts_query(@unfiltered)
    |> where([aa], aa.id == ^attempt_id)
    |> select_browse_fields()
    |> Repo.one()
  end

  defp select_browse_fields(query) do
    query
    |> select([aa, _, _, _, _, _], aa)
    |> select_merge(
      [aa, resource_attempt, resource_access, user, activity_revision, resource_revision],
      %{
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
  end

  @doc """
  Counts the attempts of the section that await manual scoring, applying the same filters as
  `browse_submitted_attempts/4`. Without options, counts the whole section.
  """
  def count_submitted_attempts(
        %Section{id: section_id},
        %BrowseOptions{} = options \\ @unfiltered
      ) do
    section_id
    |> submitted_attempts_query(options)
    |> select([aa], count(aa.id))
    |> Repo.one()
  end

  @doc """
  Returns the values the table filters can offer: one entry per student, activity resource and
  page resource with at least one attempt awaiting scoring in the section, each list sorted by
  id. Activity and page titles come from the most recently submitted pending attempt of that
  resource. The database returns one row per value, not one per pending attempt.
  """
  def filter_options(%Section{id: section_id}) do
    latest_first =
      section_id
      |> submitted_attempts_query(@unfiltered)
      |> order_by([aa], desc_nulls_last: aa.date_submitted, desc: aa.id)

    users =
      latest_first
      |> distinct([_aa, _ra, _rac, user], asc: user.id)
      |> select(
        [_aa, _ra, _rac, user],
        struct(user, [:id, :guest, :name, :given_name, :family_name])
      )
      |> Repo.all()

    activities =
      latest_first
      |> distinct([_aa, _ra, _rac, _u, activity_revision], asc: activity_revision.resource_id)
      |> select([_aa, _ra, _rac, _u, activity_revision], %{
        id: activity_revision.resource_id,
        title: activity_revision.title
      })
      |> Repo.all()

    pages =
      latest_first
      |> distinct([_aa, _ra, resource_access], asc: resource_access.resource_id)
      |> select([_aa, _ra, resource_access, _u, _ar, resource_revision], %{
        id: resource_access.resource_id,
        title: resource_revision.title
      })
      |> Repo.all()

    %{users: users, activities: activities, pages: pages}
  end

  @doc """
  Labels for filter values that no longer have pending submissions, looked up only inside the
  section: users enrolled in it, and resources of its publications. Ids that do not belong to
  the section are absent from the result.
  """
  def filter_value_labels(%Section{id: section_id, slug: slug}, %{
        user_ids: user_ids,
        activity_ids: activity_ids,
        page_ids: page_ids
      }) do
    users =
      case user_ids do
        [] ->
          %{}

        ids ->
          from(e in Enrollment,
            join: u in assoc(e, :user),
            where: e.section_id == ^section_id and u.id in ^ids,
            select: u
          )
          |> Repo.all()
          |> Map.new(&{&1.id, &1})
      end

    %{
      users: users,
      activities: resource_titles(slug, activity_ids),
      pages: resource_titles(slug, page_ids)
    }
  end

  defp resource_titles(_slug, []), do: %{}

  defp resource_titles(slug, ids) do
    slug
    |> DeliveryResolver.from_resource_id(ids)
    |> Enum.reject(&is_nil/1)
    |> Map.new(&{&1.resource_id, &1.title})
  end

  @doc """
  Returns the value of `field`'s sort key in a row of `browse_submitted_attempts/4`, captured as
  the navigation anchor for `submission_position/4`.
  """
  def sort_key_value(row, :user), do: row.user.family_name
  def sort_key_value(row, field), do: Map.fetch!(row, field)

  @doc """
  Locates the anchor attempt inside the filtered, sorted set of attempts awaiting scoring.

  The anchor is `%{id: id, key: value}` captured with `sort_key_value/2` when the attempt was
  opened. When the anchor is still in the set, its real row is used and `position` is its
  1-based index; when it left the set (scored, or excluded by the filters), a virtual row with
  the captured key takes its place, `position` is `nil` and the neighbours are the attempts
  around that place. `total` counts the eligible attempts only.
  """
  def submission_position(
        %Section{id: section_id},
        %Sorting{field: field, direction: direction},
        %BrowseOptions{} = options,
        %{id: anchor_id, key: anchor_key}
      ) do
    key = sort_key(field)

    eligible =
      section_id
      |> submitted_attempts_query(options)
      |> select([aa], %{id: aa.id, eligible: true})
      |> select_merge(^%{key: key})

    # Only asks whether the anchor is in the queue; the window query reads the whole queue.
    anchor_in_queue =
      section_id
      |> submitted_attempts_query(options)
      |> where([aa], aa.id == ^anchor_id)
      |> select([aa], aa.id)

    virtual_key = typed_anchor_key(anchor_key, sort_key_type(field))

    virtual =
      from(v in fragment("SELECT ?::bigint AS id", ^anchor_id),
        where: v.id not in subquery(anchor_in_queue),
        select: %{id: v.id, eligible: false}
      )
      |> select_merge(^%{key: virtual_key})

    union = union_all(eligible, ^virtual)

    windowed =
      case direction do
        :asc ->
          from(s in subquery(union),
            windows: [w: [order_by: [asc: s.key, asc: s.id]]],
            select: %{
              id: s.id,
              eligible: s.eligible,
              previous_id: s.id |> lag() |> over(:w),
              next_id: s.id |> lead() |> over(:w),
              position: s.id |> count() |> over(:w),
              total: fragment("count(*) FILTER (WHERE ?) OVER ()", s.eligible)
            }
          )

        :desc ->
          from(s in subquery(union),
            windows: [w: [order_by: [desc: s.key, desc: s.id]]],
            select: %{
              id: s.id,
              eligible: s.eligible,
              previous_id: s.id |> lag() |> over(:w),
              next_id: s.id |> lead() |> over(:w),
              position: s.id |> count() |> over(:w),
              total: fragment("count(*) FILTER (WHERE ?) OVER ()", s.eligible)
            }
          )
      end

    from(r in subquery(windowed), where: r.id == ^anchor_id)
    |> Repo.one()
    |> case do
      %{eligible: true} = row ->
        %{
          position: row.position,
          total: row.total,
          previous_id: row.previous_id,
          next_id: row.next_id,
          anchor_eligible?: true
        }

      %{eligible: false} = row ->
        %{
          position: nil,
          total: row.total,
          previous_id: row.previous_id,
          next_id: row.next_id,
          anchor_eligible?: false
        }
    end
  end

  defp typed_anchor_key(value, :string), do: dynamic(type(^value, :string))
  defp typed_anchor_key(value, :integer), do: dynamic(type(^value, :integer))
  defp typed_anchor_key(value, :boolean), do: dynamic(type(^value, :boolean))
  defp typed_anchor_key(value, :utc_datetime), do: dynamic(type(^value, :utc_datetime))

  defp sort_key_type(field) when field in [:user, :activity_title, :page_title], do: :string

  defp sort_key_type(field) when field in [:resource_attempt_number, :activity_type_id],
    do: :integer

  defp sort_key_type(:graded), do: :boolean
  defp sort_key_type(field), do: ActivityAttempt.__schema__(:type, field)

  defp submitted_attempts_query(section_id, %BrowseOptions{} = options) do
    filter_by_user =
      case options.user_ids do
        [] -> true
        ids -> dynamic([_aa, _ra, _rac, user, _ar, _rr], user.id in ^ids)
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
      case options.activity_ids do
        [] ->
          true

        ids ->
          dynamic(
            [_aa, _ra, _rac, _u, activity_revision, _rr],
            activity_revision.resource_id in ^ids
          )
      end

    filter_by_page =
      case options.page_ids do
        [] ->
          true

        ids ->
          dynamic([_aa, _ra, resource_access, _u, _ar, _rr], resource_access.resource_id in ^ids)
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
  end

  defp order_by_sorting(%Sorting{field: field, direction: direction}) do
    [{direction, sort_key(field)}, {direction, dynamic([aa], aa.id)}]
  end

  defp sort_key(:activity_type_id),
    do: dynamic([_aa, _ra, _rac, _u, activity_revision, _rr], activity_revision.activity_type_id)

  defp sort_key(:activity_title),
    do: dynamic([_aa, _ra, _rac, _u, activity_revision, _rr], activity_revision.title)

  defp sort_key(:page_title),
    do: dynamic([_aa, _ra, _rac, _u, _ar, resource_revision], resource_revision.title)

  defp sort_key(:resource_attempt_number),
    do: dynamic([_aa, resource_attempt, _rac, _u, _ar, _rr], resource_attempt.attempt_number)

  defp sort_key(:graded),
    do: dynamic([_aa, _ra, _rac, _u, _ar, resource_revision], resource_revision.graded)

  defp sort_key(:user), do: dynamic([_aa, _ra, _rac, user, _ar, _rr], user.family_name)

  defp sort_key(field), do: dynamic([aa], field(aa, ^field))

  @doc """
  Applies a collection of manual scores and feedbacks to the part attempts of a given activity attempt.

  The activity attempt is assumed to be fully populated with virtual attributes delivered from the
  `browse_submitted_attempts` query from this module.

  The `score_feedbacks_map` is a map of part attempt guids to `ScoreFeedback` structs that contain the
  instructor score, feedback, and the out_of value.

  If this activity is the last activity remaining in a graded page, this will finalize that graded page attempt,
  recalculate a resource access level score, and trigger LMS grade passback (if this is an LMS section and that
  section has gradepassback enabled)

  Scoring locks the activity attempt and rechecks its submitted state in the transaction before
  reading or updating its parts. Overlapping calls for the same submission cannot both save.

  It returns a tuple of `{:ok, part_attempt_guids}` if successful, `{:error, :not_pending}` when the
  attempt is no longer submitted or does not belong to the section, or `{:error, reason}` for other errors.
  """
  def apply_manual_scoring(
        %Section{slug: section_slug} = section,
        activity_attempt,
        score_feedbacks_map
      ) do
    Repo.transaction(fn ->
      state =
        from(aa in ActivityAttempt,
          join: ra in ResourceAttempt,
          on: ra.id == aa.resource_attempt_id,
          join: access in ResourceAccess,
          on: access.id == ra.resource_access_id,
          where:
            aa.id == ^activity_attempt.id and aa.attempt_guid == ^activity_attempt.attempt_guid and
              access.section_id == ^section.id,
          select: aa.lifecycle_state,
          lock: "FOR UPDATE OF a0"
        )
        |> Repo.one()

      case state do
        :submitted -> :ok
        _ -> Repo.rollback(:not_pending)
      end

      part_attempts =
        Core.get_latest_part_attempts(activity_attempt.attempt_guid)
        |> filter_part_attempts_for_manual_grading(activity_attempt)

      if part_attempts == [] do
        Repo.rollback(:no_scorable_part_attempts)
      else
        manual_part_attempt_guids =
          part_attempts
          |> Enum.filter(fn pa ->
            pa.grading_approach == :manual and pa.lifecycle_state == :submitted
          end)
          |> Enum.map(& &1.attempt_guid)

        datashop_session_id = hd(part_attempts).datashop_session_id
        client_evaluations = to_client_evaluations(part_attempts, score_feedbacks_map)

        graded = activity_attempt.graded
        resource_attempt_guid = activity_attempt.resource_attempt_guid

        mocked_part_attempts =
          Enum.map(part_attempts, fn part_attempt ->
            Map.put(part_attempt, :grading_approach, :automatic)
          end)

        case ApplyClientEvaluation.apply(
               section_slug,
               activity_attempt.attempt_guid,
               client_evaluations,
               datashop_session_id,
               enforce_client_side_eval: false,
               part_attempts_input: mocked_part_attempts
             ) do
          {:ok, _} ->
            restore_original_responses(part_attempts)

            case RollUp.rollup_evaluated(activity_attempt.attempt_guid) do
              :ok ->
                maybe_finalize_resource_attempt(section, graded, resource_attempt_guid)

              :error ->
                Repo.rollback(:rollup_failed)

              other ->
                Repo.rollback(other)
            end

            manual_part_attempt_guids

          {:error, error} ->
            Repo.rollback(error)
        end
      end
    end)
  end

  @doc """
  Repairs a stale manual grading item whose part attempts have already been evaluated,
  but whose activity attempt is still marked as submitted.
  """
  def resolve_stale_attempt(
        %Section{} = section,
        %{
          attempt_guid: activity_attempt_guid,
          graded: graded,
          resource_attempt_guid: resource_attempt_guid
        }
      ) do
    Oli.Repo.transaction(fn ->
      case RollUp.rollup_evaluated(activity_attempt_guid) do
        :ok ->
          maybe_finalize_resource_attempt(section, graded, resource_attempt_guid)
          :ok

        :error ->
          Repo.rollback(:rollup_failed)

        other ->
          Repo.rollback(other)
      end
    end)
  end

  # This function takes a list of part attempts and a map of score feedbacks from the UI
  # and converts them to a list of client evaluations that can be used to
  # to evaluate these part attempts via ApplyClientEvaluation.apply/5
  defp to_client_evaluations(part_attempts, score_feedbacks_map) do
    Enum.filter(part_attempts, fn pa ->
      pa.grading_approach == :manual and pa.lifecycle_state == :submitted
    end)
    |> Enum.map(fn pa ->
      case Map.get(score_feedbacks_map, pa.attempt_guid) do
        %{score: score, out_of: out_of, feedback: feedback} ->
          input =
            case Map.get(pa, :response) do
              %{input: input} -> input
              _ -> %{}
            end

          %{
            attempt_guid: pa.attempt_guid,
            client_evaluation: %Oli.Delivery.Attempts.Core.ClientEvaluation{
              input: input,
              feedback: %{content: wrap_in_paragraphs(feedback)},
              score: score,
              out_of: out_of
            }
          }

        _ ->
          nil
      end
    end)
    |> Enum.filter(fn client_eval -> client_eval != nil end)
  end

  @doc """
  Keeps the part attempts manual scoring works on: an adaptive activity keeps only the parts
  `AdaptiveParts.manual_gradeable_part_ids/1` allows; any other activity keeps every part.
  """
  def filter_part_attempts_for_manual_grading(
        part_attempts,
        %{activity_type_id: activity_type_id, revision: revision}
      ) do
    if AdaptiveParts.adaptive_activity?(%{activity_type_id: activity_type_id}) do
      allowed_part_ids = AdaptiveParts.manual_gradeable_part_ids(revision.content)
      Enum.filter(part_attempts, &MapSet.member?(allowed_part_ids, &1.part_id))
    else
      part_attempts
    end
  end

  # Restores the original response structure for part attempts after manual scoring
  defp restore_original_responses(original_part_attempts) do
    part_inputs =
      Enum.map(original_part_attempts, fn part_attempt ->
        %{
          attempt_guid: part_attempt.attempt_guid,
          response: part_attempt.response
        }
      end)

    # Use the existing save_student_input function to update the response attribute
    case Oli.Delivery.Attempts.ActivityLifecycle.save_student_input(part_inputs) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Oli.Utils.log_error("Failed to restore original responses", error)
        :error
    end
  end

  defp maybe_finalize_resource_attempt(section, false, resource_attempt_guid) do
    resource_attempt =
      Oli.Delivery.Attempts.Core.get_resource_attempt(attempt_guid: resource_attempt_guid)
      |> Oli.Repo.preload(:revision)

    case resource_attempt do
      %ResourceAttempt{lifecycle_state: :submitted, resource_access_id: resource_access_id} ->
        resource_access = Oli.Repo.get(ResourceAccess, resource_access_id)

        effective_settings =
          Settings.get_combined_settings(
            resource_attempt.revision,
            section.id,
            resource_access.user_id
          )

        case Oli.Delivery.Attempts.PageLifecycle.Graded.roll_up_activities_to_resource_attempt(
               resource_attempt,
               effective_settings
             ) do
          {:ok, _resource_attempt} -> {:ok, resource_attempt_guid}
          other -> other
        end

      _ ->
        {:ok, resource_attempt_guid}
    end
  end

  defp maybe_finalize_resource_attempt(section, true, resource_attempt_guid) do
    resource_attempt =
      Oli.Delivery.Attempts.Core.get_resource_attempt(attempt_guid: resource_attempt_guid)
      |> Oli.Repo.preload(:revision)

    resource_access = Oli.Repo.get(ResourceAccess, resource_attempt.resource_access_id)

    effective_settings =
      Oli.Delivery.Settings.get_combined_settings(
        resource_attempt.revision,
        section.id,
        resource_access.user_id
      )

    case Oli.Delivery.Attempts.PageLifecycle.Graded.roll_up_activities_to_resource_attempt(
           resource_attempt,
           effective_settings
         ) do
      {:ok,
       %ResourceAttempt{
         id: resource_attempt_id,
         lifecycle_state: :evaluated,
         revision: revision,
         resource_access_id: resource_access_id,
         was_late: was_late
       }} ->
        case RewardHandoff.record_if_active_thompson(resource_attempt_id, section.id) do
          :ok -> :ok
          {:error, reason} -> Repo.rollback({:reward_processing_failed, reason})
        end

        resource_access = Oli.Repo.get(ResourceAccess, resource_access_id)

        effective_settings =
          Oli.Delivery.Settings.get_combined_settings(
            revision,
            section.id,
            resource_access.user_id
          )

        Oli.Delivery.Attempts.PageLifecycle.Graded.roll_up_resource_attempts_to_access(
          effective_settings,
          section.slug,
          resource_access_id,
          was_late
        )
        |> maybe_initiate_grade_passback(section)

      e ->
        e
    end
  end

  defp maybe_initiate_grade_passback({:ok, %ResourceAccess{id: resource_access_id}}, %Section{
         id: section_id,
         grade_passback_enabled: true
       }) do
    Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.create(
      section_id,
      resource_access_id,
      :inline
    )
  end

  defp maybe_initiate_grade_passback(other, _) do
    other
  end

  defp wrap_in_paragraphs(text) do
    String.split(text, "\n")
    |> Enum.map(fn text ->
      %{type: "p", children: [%{text: text}]}
    end)
  end
end
