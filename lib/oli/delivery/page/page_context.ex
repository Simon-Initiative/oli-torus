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
    :latest_attempts,
    :bib_revisions
  ]
  defstruct [
    :review_mode,
    :page,
    :progress_state,
    :resource_attempts,
    :activities,
    :objectives,
    :latest_attempts,
    :bib_revisions
  ]

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.{AttemptState, HistorySummary}
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Delivery.Page.PageContext
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Page.ObjectivesRollup
  alias Oli.Delivery.Sections.Section

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
  def create_for_review(section_slug, attempt_guid, _) do
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

    page_revision = hd(resource_attempts).revision

    %PageContext{
      review_mode: true,
      page: page_revision,
      progress_state: progress_state,
      resource_attempts: resource_attempts,
      activities: activities,
      objectives:
        rollup_objectives(page_revision, latest_attempts, DeliveryResolver, section_slug),
      latest_attempts: latest_attempts,
      bib_revisions: assemble_bib_entrys(page_revision.content, activities, section_slug)
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
  def create_for_visit(
        %Section{slug: section_slug, id: section_id},
        page_slug,
        user
      ) do
    # resolve the page revision per section
    page_revision = DeliveryResolver.from_revision_slug(section_slug, page_slug)

    Attempts.track_access(page_revision.resource_id, section_id, user.id)

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
          value = assemble_final_context(state, resource_attempt, latest_attempts, page_revision)
          value

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
      objectives:
        rollup_objectives(page_revision, latest_attempts, DeliveryResolver, section_slug),
      latest_attempts: latest_attempts,
      bib_revisions: assemble_bib_entrys(page_revision.content, activities, section_slug)
    }
  end

  def assemble_bib_entrys(page_content, activity_summaries, section_slug) do
    bib_ids = Map.get(page_content, "bibrefs", []) |> Enum.reduce([], fn x, acc ->
      if Map.get(x, "type") == "activity" do
        acc
      else
        acc ++ [Map.get(x, "id")]
      end
    end)

    merged_bib_ids =
      if activity_summaries != nil do
        Enum.reduce(Map.values(activity_summaries), bib_ids, fn x, acc ->
          if Map.has_key?(x, :bib_refs) do
            acc ++ Enum.reduce(x.bib_refs, [], fn y, acx ->
              acx ++ [Map.get(y, "id")]
            end)
          else
            acc
          end
        end)
      else
        bib_ids
      end

    # Remove duplicates
    merged_bib_ids = Enum.reduce(merged_bib_ids, [],  fn x, acc ->
      if Enum.any?(acc, fn i -> i == x end) do
        acc
      else
        acc ++ [x]
      end
    end)

    bib_revisions = DeliveryResolver.from_resource_id(section_slug, merged_bib_ids)

    Enum.map(bib_revisions, fn x -> serialize_revision(x, merged_bib_ids) end)
  end

  defp assemble_final_context(state, resource_attempt, latest_attempts, %{
         content: %{"advancedDelivery" => true}
       }) do
    {state, [resource_attempt], latest_attempts, latest_attempts}
  end

  defp assemble_final_context(state, resource_attempt, latest_attempts, page_revision) do
    {state, [resource_attempt], latest_attempts,
     ActivityContext.create_context_map(page_revision.graded, latest_attempts)}
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

  defp serialize_revision(%Oli.Resources.Revision{} = revision, merged_bib_ids) do
    ordinal = Enum.find_index(merged_bib_ids, fn x -> x == revision.resource_id end) + 1
    %{
      title: revision.title,
      id: revision.resource_id,
      slug: revision.slug,
      content: revision.content,
      ordinal: ordinal
    }
  end
end
