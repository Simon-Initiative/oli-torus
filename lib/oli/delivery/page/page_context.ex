defmodule Oli.Delivery.Page.PageContext do
  @moduledoc """
  Defines the context required to render a page in delivery mode.
  """
  use Appsignal.Instrumentation.Decorators

  @enforce_keys [
    :user,
    :review_mode,
    :page,
    :progress_state,
    :resource_attempts,
    :activities,
    :objectives,
    :latest_attempts,
    :bib_revisions,
    :historical_attempts,
    :collab_space_config,
    :is_instructor,
    :is_student,
    :effective_settings
  ]
  defstruct [
    :user,
    :review_mode,
    :page,
    :progress_state,
    :resource_attempts,
    :activities,
    :objectives,
    :latest_attempts,
    :bib_revisions,
    :historical_attempts,
    :collab_space_config,
    :is_instructor,
    :is_student,
    :effective_settings,
    :license
  ]

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.{AttemptState, HistorySummary}
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Delivery.Page.PageContext
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Page.ObjectivesRollup
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Collaboration
  alias Oli.Utils.BibUtils

  @doc """
  Creates the page context required to render a page for reviewing a historical
  attempt.

  The key task performed here is the resolution of all referenced objectives
  and activities that may be present in the content of the page. This
  information is collected and then assembled in a fashion that can be given
  to a renderer.
  """
  @decorate transaction_event()
  def create_for_review(section_slug, attempt_guid, user, is_admin?) do
    section = Oli.Delivery.Sections.get_section_by_slug(section_slug)

    {progress_state, resource_attempts, latest_attempts, activities, user_for_attempt,
     effective_settings} =
      case PageLifecycle.review(attempt_guid) do
        {:ok,
         {state,
          %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: latest_attempts}}} ->
          user_for_attempt = Attempts.get_user_from_attempt(resource_attempt)

          effective_settings =
            Oli.Delivery.Settings.get_combined_settings(
              resource_attempt.revision,
              section.id,
              user_for_attempt.id
            )

          # For testing feedback_mode, uncomment the following
          # date = DateTime.utc_now() |> DateTime.add(-1, :day)
          # effective_settings = %{effective_settings | feedback_mode: :scheduled, feedback_scheduled_date: date}

          {progress_state, resource_attempts, latest_attempts, activities} =
            assemble_final_context(
              state,
              resource_attempt,
              latest_attempts,
              resource_attempt.revision,
              Oli.Delivery.Settings.show_feedback?(effective_settings)
            )

          {progress_state, resource_attempts, latest_attempts, activities, user_for_attempt,
           effective_settings}

        {:error, _} ->
          {:error, [], %{}}
      end

    resource_attempt = hd(resource_attempts)
    page_revision = resource_attempt.revision

    summaries = if activities != nil, do: Map.values(activities), else: []

    bib_revisions =
      BibUtils.assemble_bib_entries(
        page_revision.content,
        summaries,
        fn r -> Map.get(r, :bib_refs, []) end,
        section_slug,
        DeliveryResolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {summary, ordinal} -> BibUtils.serialize_revision(summary, ordinal) end)

    {:ok, collab_space_config} =
      Collaboration.get_collab_space_config_for_page_in_section(page_revision.slug, section_slug)

    # Determine if the current user (not necessarily the user of this attempt) is instructor
    # or is student
    {is_instructor, is_student} =
      case is_admin? do
        true ->
          {true, false}

        _ ->
          user_roles = Sections.get_user_roles(user, section_slug)
          {user_roles.is_instructor?, user_roles.is_student?}
      end

    %PageContext{
      user: user_for_attempt,
      review_mode: true,
      page: page_revision,
      progress_state: progress_state,
      resource_attempts: resource_attempts,
      activities: activities,
      objectives:
        rollup_objectives(page_revision, latest_attempts, DeliveryResolver, section_slug),
      latest_attempts: latest_attempts,
      bib_revisions: bib_revisions,
      historical_attempts: retrieve_historical_attempts(hd(resource_attempts)),
      collab_space_config: collab_space_config,
      is_instructor: is_instructor,
      is_student: is_student,
      effective_settings: effective_settings
    }
  end

  # For the given resource attempt, retrieve all historical activity attempt records,
  # assembling them into a map of activity_id to a list of the activity attempts, including
  # the latest attempt
  @decorate transaction_event()
  defp retrieve_historical_attempts(resource_attempt) do
    Oli.Delivery.Attempts.Core.get_all_activity_attempts(resource_attempt.id)
    |> Enum.sort(fn a1, a2 -> a1.attempt_number < a2.attempt_number end)
    |> Enum.reduce(%{}, fn a, m ->
      appended = Map.get(m, a.resource_id, []) ++ [a]
      Map.put(m, a.resource_id, appended)
    end)
  end

  @doc """
  Creates the page context required to render a page for visiting a current or new
  attempt.

  The key task performed here is the resolution of all referenced objectives
  and activities that may be present in the content of the page. This
  information is collected and then assembled in a fashion that can be given
  to a renderer.

  The `opts` parameter is a keyword list that can contain the following options:
  - track_access: a boolean that determines whether to track access to the page. Defaults to true.
  """
  @decorate transaction_event()
  def create_for_visit(
        %Section{slug: section_slug, id: section_id},
        page_slug,
        user,
        datashop_session_id,
        opts \\ [track_access: true]
      ) do
    # resolve the page revision per section
    page_revision =
      Appsignal.instrument("resolve page revision", fn ->
        DeliveryResolver.from_revision_slug(section_slug, page_slug)
      end)

    effective_settings =
      Oli.Delivery.Settings.get_combined_settings(page_revision, section_id, user.id)

    if opts[:track_access],
      do: Attempts.track_access(page_revision.resource_id, section_id, user.id)

    activity_provider = &Oli.Delivery.ActivityProvider.provide/6

    {progress_state, resource_attempts, latest_attempts, activities} =
      Appsignal.instrument("PageLifecycle.visit", fn ->
        case PageLifecycle.visit(
               page_revision,
               section_slug,
               datashop_session_id,
               user,
               effective_settings,
               activity_provider
             ) do
          {:ok, {:not_started, %HistorySummary{resource_attempts: resource_attempts}}} ->
            {:not_started, resource_attempts, %{}, nil}

          {:ok,
           {state,
            %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: latest_attempts}}} ->
            assemble_final_context(state, resource_attempt, latest_attempts, page_revision, true)

          {:error, _} ->
            {:error, [], %{}}
        end
      end)

    # Fetch the revision pinned to the resource attempt if it was revised since this attempt began. This
    # is what enables existing attempts that are being revisited after a change was published to the page
    # to display the old content
    page_revision =
      if progress_state == :revised or progress_state == :in_review do
        Oli.Resources.get_revision!(hd(resource_attempts).revision_id)
      else
        page_revision
      end

    summaries = if activities != nil, do: Map.values(activities), else: []

    bib_revisions =
      BibUtils.assemble_bib_entries(
        page_revision.content,
        summaries,
        fn r -> Map.get(r, :bib_refs, []) end,
        section_slug,
        DeliveryResolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {summary, ordinal} -> BibUtils.serialize_revision(summary, ordinal) end)

    {:ok, collab_space_config} =
      Appsignal.instrument("get collab space config", fn ->
        Collaboration.get_collab_space_config_for_page_in_section(
          page_revision.slug,
          section_slug
        )
      end)

    user_roles = Sections.get_user_roles(user, section_slug)

    license = Oli.Authoring.Course.get_project_license(page_revision.id, section_slug)

    %PageContext{
      license: license,
      user: user,
      review_mode: false,
      page: page_revision,
      progress_state: progress_state,
      resource_attempts: resource_attempts,
      activities: activities,
      objectives:
        rollup_objectives(page_revision, latest_attempts, DeliveryResolver, section_slug),
      latest_attempts: latest_attempts,
      bib_revisions: bib_revisions,
      historical_attempts: nil,
      collab_space_config: collab_space_config,
      is_instructor: user_roles.is_instructor?,
      is_student: user_roles.is_student?,
      effective_settings: effective_settings
    }
  end

  defp assemble_final_context(
         state,
         resource_attempt,
         latest_attempts,
         %{
           content: %{"advancedDelivery" => true}
         },
         _
       ) do
    {state, [resource_attempt], latest_attempts, latest_attempts}
  end

  @decorate transaction_event()
  defp assemble_final_context(
         state,
         resource_attempt,
         latest_attempts,
         page_revision,
         show_feedback
       ) do
    content_for_ordinal_assignment =
      case resource_attempt.content do
        nil -> page_revision.content
        t -> t
      end

    final_context =
      ActivityContext.create_context_map(
        page_revision.graded,
        latest_attempts,
        resource_attempt,
        page_revision,
        assign_ordinals_from: content_for_ordinal_assignment,
        show_feedback: show_feedback
      )

    {state, [resource_attempt], latest_attempts, final_context}
  end

  # for a map of activity ids to latest attempt tuples (where the first tuple item is the activity attempt)
  # return the parent objective revisions of all attached objectives
  # if an attached objective is a parent, include that in the return list
  defp rollup_objectives(%{content: %{"advancedDelivery" => true}}, _, _, _) do
    []
  end

  @decorate transaction_event()
  defp rollup_objectives(page_rev, latest_attempts, resolver, section_slug) do
    activity_revisions =
      Enum.map(latest_attempts, fn {_, {%{revision: revision}, _}} -> revision end)

    ObjectivesRollup.rollup_objectives(page_rev, activity_revisions, resolver, section_slug)
  end
end
