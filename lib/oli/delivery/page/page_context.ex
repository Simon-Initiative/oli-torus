defmodule Oli.Delivery.Page.PageContext do
  @moduledoc """
  Defines the context required to render a page in delivery mode.
  """

  @enforce_keys [
    :review_mode,
    :page,
    :progress_state,
    :resource_attempts,
    :activities,
    :objectives,
    :latest_attempts
  ]
  defstruct [
    :review_mode,
    :page,
    :progress_state,
    :resource_attempts,
    :activities,
    :objectives,
    :latest_attempts
  ]

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.{AttemptState, HistorySummary}
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Delivery.Page.PageContext
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Page.ObjectivesRollup

  @doc """
  Creates the page context required to render a page for reviewing a historical
  attempt.

  The key task performed here is the resolution of all referenced objectives
  and activities that may be present in the content of the page. This
  information is collected and then assembled in a fashion that can be given
  to a renderer.
  """
  @spec create_for_review(String.t(), String.t(), Oli.Accounts.User) :: %PageContext{}
  def create_for_review(section_slug, attempt_guid, _) do
    {progress_state, resource_attempts, latest_attempts, activities, page_revision} =
      case PageLifecycle.review(attempt_guid) do
        {:ok,
         {state,
          %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: latest_attempts}}} ->
          page_revision = Oli.Resources.get_revision!(resource_attempt.revision_id)

          {state, [resource_attempt], latest_attempts,
           ActivityContext.create_context_map(page_revision.graded, latest_attempts),
           page_revision}

        {:error, _} ->
          {:error, [], %{}}
      end

    %PageContext{
      review_mode: true,
      page: page_revision,
      progress_state: progress_state,
      resource_attempts: resource_attempts,
      activities: activities,
      objectives: rollup_objectives(latest_attempts, DeliveryResolver, section_slug),
      latest_attempts: latest_attempts
    }
  end

  @doc """
  Creates the page context required to render a page for visiting a current or new
  attempt.

  The key task performed here is the resolution of all referenced objectives
  and activities that may be present in the content of the page. This
  information is collected and then assembled in a fashion that can be given
  to a renderer.
  """
  @spec create_for_visit(String.t(), String.t(), Oli.Accounts.User) ::
          %PageContext{}
  def create_for_visit(section_slug, page_slug, user) do
    # resolve the page revision per section
    page_revision = DeliveryResolver.from_revision_slug(section_slug, page_slug)

    Attempts.track_access(page_revision.resource_id, section_slug, user.id)

    activity_provider = &Oli.Delivery.ActivityProvider.provide/3

    {progress_state, resource_attempts, latest_attempts, activities} =
      case PageLifecycle.visit(
             page_revision,
             section_slug,
             user.id,
             activity_provider
           ) do
        {:ok, {:not_started, %HistorySummary{resource_attempts: resource_attempts}}} ->
          {:not_started, resource_attempts, %{}, nil}

        {:ok,
         {state,
          %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: latest_attempts}}} ->
          {state, [resource_attempt], latest_attempts,
           ActivityContext.create_context_map(page_revision.graded, latest_attempts)}

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

    %PageContext{
      review_mode: false,
      page: page_revision,
      progress_state: progress_state,
      resource_attempts: resource_attempts,
      activities: activities,
      objectives: rollup_objectives(latest_attempts, DeliveryResolver, section_slug),
      latest_attempts: latest_attempts
    }
  end

  # for a map of activity ids to latest attempt tuples (where the first tuple item is the activity attempt)
  # return the parent objective revisions of all attached objectives
  # if an attached objective is a parent, include that in the return list
  defp rollup_objectives(latest_attempts, resolver, section_slug) do
    Enum.map(latest_attempts, fn {_, {%{revision: revision}, _}} -> revision end)
    |> ObjectivesRollup.rollup_objectives(resolver, section_slug)
  end
end
