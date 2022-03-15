defmodule Oli.Delivery.Attempts.ManualGrading do
  import Ecto.Query, warn: false

  @moduledoc """
  Modeule for manual activity grading.
  """

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias Oli.Resources.Revision

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

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
        [aa, _resource_attempt, _resource_access, user, activity_revision, resource_revision],
        %{
          total_count: fragment("count(*) OVER()"),
          activity_type_id: activity_revision.activity_type_id,
          activity_title: activity_revision.title,
          page_title: resource_revision.title,
          graded: resource_revision.graded,
          user: user
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
end
