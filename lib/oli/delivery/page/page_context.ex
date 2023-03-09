defmodule Oli.Delivery.Page.PageContext do
  @moduledoc """
  Defines the context required to render a page in delivery mode.
  """

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
    :is_student
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
    :is_student
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
  @spec create_for_review(String.t(), String.t(), Oli.Accounts.User) ::
          %PageContext{}
  def create_for_review(section_slug, attempt_guid, user) do
    {progress_state, resource_attempts, latest_attempts, activities} =
      case PageLifecycle.review(attempt_guid) do
        {:ok,
         {state,
          %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: latest_attempts}}} ->
          assemble_final_context(
            state,
            resource_attempt,
            latest_attempts,
            resource_attempt.revision
          )

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

    %PageContext{
      user: Attempts.get_user_from_attempt(resource_attempt),
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
      is_instructor: Sections.is_instructor?(user, section_slug),
      is_student: Sections.is_student?(user, section_slug)
    }
  end

  # For the given resource attempt, retrieve all historical activity attempt records,
  # assembling them into a map of activity_id to a list of the activity attempts, including
  # the latest attempt
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
  """
  def create_for_visit(
        %Section{slug: section_slug, id: section_id},
        page_slug,
        user,
        datashop_session_id
      ) do
    # resolve the page revision per section
    page_revision = DeliveryResolver.from_revision_slug(section_slug, page_slug)

    Attempts.track_access(page_revision.resource_id, section_id, user.id)

    activity_provider = &Oli.Delivery.ActivityProvider.provide/4

    {progress_state, resource_attempts, latest_attempts, activities} =
      case PageLifecycle.visit(
             page_revision,
             section_slug,
             datashop_session_id,
             user.id,
             activity_provider
           ) do
        {:ok, {:not_started, %HistorySummary{resource_attempts: resource_attempts}}} ->
          {:not_started, resource_attempts, %{}, nil}

        {:ok,
         {state,
          %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: latest_attempts}}} ->
          assemble_final_context(state, resource_attempt, latest_attempts, page_revision)

        {:error, _} ->
          {:error, [], %{}}
      end

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
      Collaboration.get_collab_space_config_for_page_in_section(page_revision.slug, section_slug)

    %PageContext{
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
      is_instructor: Sections.is_instructor?(user, section_slug),
      is_student: Sections.is_student?(user, section_slug)
    }
  end

  defp assemble_final_context(state, resource_attempt, latest_attempts, %{
         content: %{"advancedDelivery" => true}
       }) do
    {state, [resource_attempt], latest_attempts, latest_attempts}
  end

  defp assemble_final_context(state, resource_attempt, latest_attempts, page_revision) do
    content_for_ordinal_assignment =
      case resource_attempt.content do
        nil -> page_revision.content
        t -> t
      end

    {state, [resource_attempt], latest_attempts,
     ActivityContext.create_context_map(
       page_revision.graded,
       latest_attempts,
       resource_attempt,
       page_revision,
       assign_ordinals_from: content_for_ordinal_assignment
     )}
  end

  # for a map of activity ids to latest attempt tuples (where the first tuple item is the activity attempt)
  # return the parent objective revisions of all attached objectives
  # if an attached objective is a parent, include that in the return list
  defp rollup_objectives(%{content: %{"advancedDelivery" => true}}, _, _, _) do
    []
  end

  defp rollup_objectives(page_rev, latest_attempts, resolver, section_slug) do
    activity_revisions =
      Enum.map(latest_attempts, fn {_, {%{revision: revision}, _}} -> revision end)

    ObjectivesRollup.rollup_objectives(page_rev, activity_revisions, resolver, section_slug)
  end
end
