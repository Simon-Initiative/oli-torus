defmodule Oli.Delivery.Page.PageContext do

  @moduledoc """
  Defines the context required to render a page in delivery mode.
  """

  @enforce_keys [:summary, :page, :progress_state, :resource_attempts, :activities, :objectives, :previous_page, :next_page]
  defstruct [:summary, :page, :progress_state, :resource_attempts, :activities, :objectives, :previous_page, :next_page]

  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Delivery.Page.PageContext
  alias Oli.Resources.Revision
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Student.Summary

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
  def create_page_context(context_id, page_slug, user, container_id \\ nil) do

    # resolve the page revision per context_id
    page_revision = DeliveryResolver.from_revision_slug(context_id, page_slug)

    # track access to this resource
    Attempts.track_access(page_revision.resource_id, context_id, user.id)

    activity_provider = &Oli.Delivery.ActivityProvider.provide/2

    {progress_state, resource_attempts, activities} = case Attempts.determine_resource_attempt_state(page_revision, context_id, user.id, activity_provider) do
      {:ok, {:not_started, {_, resource_attempts}}} -> {:not_started, resource_attempts, nil}
      {:ok, {state, {resource_attempt, latest_attempts}}} -> {state, [resource_attempt], ActivityContext.create_context_map(page_revision.graded, latest_attempts)}
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

    {previous, next} = retrieve_previous_next(context_id, page_revision, container_id)

    {:ok, summary} = Summary.get_summary(context_id, user)

    %PageContext{
      summary: summary,
      page: page_revision,
      progress_state: progress_state,
      resource_attempts: resource_attempts,
      activities: activities,
      objectives: [],
      previous_page: previous,
      next_page: next
    }
  end

  # We combine retrieve objective titles and previous next page
  # information in one step so that we can do all their revision
  # resolution in one step.
  defp retrieve_previous_next(context_id,
    %Revision{objectives: %{"attached" => objective_ids}} = page_revision, container_id) do

    # if container_id is nil we assume it is the root
    container = case container_id do
      nil -> DeliveryResolver.root_resource(context_id)
      id -> DeliveryResolver.from_resource_id(context_id, id)
    end

    previous_next = determine_previous_next(container, page_revision.resource_id)

    # resolve all of these references, all at once, storing
    # them in a map based on their resource_id as the key
    all_resources = Enum.filter(previous_next, fn a -> a != nil end)

    revisions = DeliveryResolver.from_resource_id(context_id, all_resources)
    |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)

    previous = Map.get(revisions, Enum.at(previous_next, 0))
    next = Map.get(revisions, Enum.at(previous_next, 1))

    {previous, next}
  end

  defp rollup_objectives(activities, resolver) do

    all_attached_objectives = Enum.reduce(activities, MapSet.new(), fn {_, %{objectives: objectives}}, all ->
      Enum.map(objectives, fn {_, ids} -> ids end)
      |> List.flatten
      |> MapSet.new
      |> MapSet.union(all)
    end)
    |> MapSet.to_list



  end

  defp determine_previous_next(%{children: children}, page_resource_id) do

    index = Enum.find_index(children, fn id -> id == page_resource_id end)

    case {index, length(children) - 1} do
      {_, 0} -> [nil, nil]
      {0, _} -> [nil, Enum.at(children, 1)]
      {a, a} -> [Enum.at(children, a - 1), nil]
      {a, _} -> [Enum.at(children, a - 1), Enum.at(children, a + 1)]
    end
  end

end
