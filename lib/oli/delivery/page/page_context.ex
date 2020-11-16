defmodule Oli.Delivery.Page.PageContext do

  @moduledoc """
  Defines the context required to render a page in delivery mode.
  """

  @enforce_keys [:summary, :page, :progress_state, :resource_attempts, :activities, :objectives, :previous_page, :next_page]
  defstruct [:summary, :page, :progress_state, :resource_attempts, :activities, :objectives, :previous_page, :next_page]

  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Delivery.Page.PageContext
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Student.Summary
  alias Oli.Delivery.Page.ObjectivesRollup
  alias Oli.Resources.ResourceType

  @doc """
  Creates the page context required to render a page in delivery model, based
  off of the section context id, the slug of the page to render, and an
  optional id of the parent container that the page exists within. If not
  specified, the container is assumed to be the root resource of the publication.

  The key task performed here is the resolution of all referenced objectives
  and activities that may be present in the content of the page. This
  information is collected and then assembled in a fashion that can be given
  to a renderer.
  """
  @spec create_page_context(String.t, String.t, Oli.Accounts.User) :: %PageContext{}
  def create_page_context(context_id, page_slug, user) do

    # resolve the page revision per context_id
    page_revision = DeliveryResolver.from_revision_slug(context_id, page_slug)

    # track access to this resource
    Attempts.track_access(page_revision.resource_id, context_id, user.id)

    activity_provider = &Oli.Delivery.ActivityProvider.provide/2

    {progress_state, resource_attempts, latest_attempts, activities} = case Attempts.determine_resource_attempt_state(page_revision, context_id, user.id, activity_provider) do
      {:ok, {:not_started, {_, resource_attempts}}} -> {:not_started, resource_attempts, %{}, nil}
      {:ok, {state, {resource_attempt, latest_attempts}}} -> {state, [resource_attempt], latest_attempts, ActivityContext.create_context_map(page_revision.graded, latest_attempts)}
      {:error, _} -> {:error, [], %{}}
    end

    # Fetch the revision pinned to the resource attempt if it was revised since this attempt began. This
    # is what enables existing attempts that are being revisited after a change was published to the page
    # to display the old content
    page_revision = if progress_state == :revised do
      Oli.Resources.get_revision!(hd(resource_attempts).revision_id)
    else
      page_revision
    end

    {:ok, summary} = Summary.get_summary(context_id, user)

    {previous, next} = determine_previous_next(flatten_hierarchy(summary.hierarchy), page_revision)

    %PageContext{
      summary: summary,
      page: page_revision,
      progress_state: progress_state,
      resource_attempts: resource_attempts,
      activities: activities,
      objectives: rollup_objectives(latest_attempts, DeliveryResolver, context_id),
      previous_page: previous,
      next_page: next
    }
  end

  defp flatten_hierarchy([]), do: []
  defp flatten_hierarchy([h | t]) do
    if ResourceType.get_type_by_id(h.revision.resource_type_id) == "container" do
      []
    else
      [h]
    end ++ flatten_hierarchy(h.children) ++ flatten_hierarchy(t)
  end

  # for a map of activity ids to latest attempt tuples (where the first tuple item is the activity attempt)
  # return the parent objective revisions of all attached objectives
  # if an attached objective is a parent, include that in the return list
  defp rollup_objectives(latest_attempts, resolver, context_id) do
    Enum.map(latest_attempts, fn {_, {%{ revision: revision }, _}} -> revision end)
    |> ObjectivesRollup.rollup_objectives(resolver, context_id)
  end

  defp determine_previous_next(hierarchy, revision) do

    index = Enum.find_index(hierarchy, fn node -> node.revision.id == revision.id end)

    case {index, length(hierarchy) - 1} do
      {nil, _} -> {nil, nil}
      {_, nil} -> {nil, nil}
      {_, 0} -> {nil, nil}
      {0, _} -> {nil, Enum.at(hierarchy, 1).revision}
      {a, a} -> {Enum.at(hierarchy, a - 1).revision, nil}
      {a, _} -> {Enum.at(hierarchy, a - 1).revision, Enum.at(hierarchy, a + 1).revision}
    end
  end

end
