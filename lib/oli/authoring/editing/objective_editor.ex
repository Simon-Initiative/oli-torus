defmodule Oli.Authoring.Editing.ObjectiveEditor do
  import Ecto.Query, warn: false

  alias Oli.Resources.Revision
  alias Oli.Publishing
  alias Oli.Authoring.Course.Project

  @doc """
  Checks whether removing a sub-objective from the given parent would delete its
  final association. Tagged sub-objectives cannot be deleted.
  """
  @spec sub_objective_delete_eligibility(binary(), %Project{}, binary()) ::
          {:ok, %Revision{}} | {:error, :associated | :not_associated | :not_found | :tagged}
  def sub_objective_delete_eligibility(revision_slug, %Project{} = project, parent_slug) do
    publication = Publishing.project_working_publication(project.slug)
    revisions = objective_revisions(publication.id, slugs: [revision_slug, parent_slug])

    with {:ok, sub_objective, parent} <-
           associated_revisions(revisions, revision_slug, parent_slug),
         :ok <- final_association_eligibility(sub_objective, parent, publication.id) do
      {:ok, sub_objective}
    end
  end

  @doc "Returns the sub-objective and parent revisions with these slugs, if the parent contains it."
  def associated_revisions(revisions, revision_slug, parent_slug) do
    with %{} = sub_objective <- Enum.find(revisions, &(&1.slug == revision_slug)),
         %{} = parent <- Enum.find(revisions, &(&1.slug == parent_slug)),
         true <- sub_objective.resource_id in parent.children do
      {:ok, sub_objective, parent}
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_associated}
    end
  end

  @doc "Returns `:ok` when `parent` is the last parent of an untagged sub-objective."
  def final_association_eligibility(sub_objective, parent, publication_id) do
    case Publishing.objective_parent_ids(sub_objective.resource_id, publication_id) do
      [parent_id] when parent_id == parent.resource_id ->
        case Publishing.objective_referenced?(sub_objective.resource_id, publication_id) do
          true -> {:error, :tagged}
          false -> :ok
        end

      _parents ->
        {:error, :associated}
    end
  end

  @doc "Returns the objective revisions of a publication (options of `Publishing.get_objective_mappings_by_publication/2`)."
  def objective_revisions(publication_id, opts) do
    publication_id
    |> Publishing.get_objective_mappings_by_publication(opts)
    |> Enum.map(& &1.revision)
  end

  @doc """
  Previews an objective detachment, returning back references to the pages and
  activities that the objective is attached to (if any).  These references are in
  the form of a map of key-values:

  %{
    resource_id: the resource id of the attaching resource
    title: the title of the resource
    slug: the slug
    part: either 'attached' for pages, or the part id for activities for where
          the objective is attached.
  }

  The return value of this function is:

  %{
    attachments: {page_references[], activity_references[]},
    parent_pages: map of the activity reference resource ids to their parent page resource ids
    locked_by: map of page resource ids to publish resource records for those pages that are
       currently locked for editing
  }

  """
  @spec preview_objective_detatchment(any(), Oli.Authoring.Course.Project.t()) :: %{
          attachments: {any, any},
          locked_by: map(),
          parent_pages: map()
        }
  def preview_objective_detatchment(resource_id, %Project{} = project) do
    publication = Publishing.project_working_publication(project.slug)

    # find all attachments
    case Publishing.find_objective_attachments(resource_id, publication.id) do
      # if no attachments
      [] ->
        %{attachments: {[], []}, locked_by: %{}, parent_pages: %{}, locked_banked_activities: %{}}

      # otherwise we need to see which attachments are currently locked for edit
      attachments ->
        # partition the attachments between pages and activities
        {pages, activities} = partition_attachments(attachments)

        # activites can be duplicatd if more than one part has an attachment, so
        # dedupe for the purposes of detachment
        distinct_activities = dedupe_activities(activities)

        # for those activities, determine which pages they exist in and combine
        # that set of pages with the set of pages that contain the objective
        # directly attached to it
        {parent_pages, unified_pages} =
          case distinct_activities do
            [] ->
              {%{}, MapSet.new(Enum.map(pages, fn p -> p.resource_id end))}

            a ->
              activity_ids = Enum.map(a, fn e -> Map.get(e, :resource_id) end)
              parent_pages = Publishing.determine_parent_pages(activity_ids, publication.id)
              unified_pages = unify_pages(parent_pages, pages)
              {parent_pages, unified_pages}
          end

        # now we can determine for all pages, which users might be currently editing
        locked_by =
          Publishing.retrieve_lock_info(MapSet.to_list(unified_pages), publication.id)
          |> Enum.reduce(%{}, fn mapping, m ->
            case Oli.Authoring.Locks.expired_or_empty?(mapping) do
              true -> m
              false -> Map.put(m, mapping.resource_id, mapping)
            end
          end)

        locked_banked_activities =
          case directly_locked_activities(distinct_activities, parent_pages) do
            [] ->
              %{}

            activities ->
              Enum.map(activities, fn a -> a.resource_id end)
              |> Publishing.retrieve_lock_info(publication.id)
              |> Enum.reduce(%{}, fn mapping, m ->
                case Oli.Authoring.Locks.expired_or_empty?(mapping) do
                  true -> m
                  false -> Map.put(m, mapping.resource_id, mapping)
                end
              end)
          end

        %{
          attachments: {pages, distinct_activities},
          locked_by: locked_by,
          parent_pages: parent_pages,
          locked_banked_activities: locked_banked_activities
        }
    end
  end

  # split the found attachments into separate lists for pages and activies, returning them
  # as a two element tuple
  defp partition_attachments(attachments) do
    Enum.reduce(attachments, {[], []}, fn e, {p, a} ->
      case e.part do
        "attached" -> {p ++ [e], a}
        _ -> {p, a ++ [e]}
      end
    end)
  end

  # For a list of activity attachment references, dedupe them.
  defp dedupe_activities(activities) do
    {deduped, _} =
      Enum.reduce(activities, {[], MapSet.new()}, fn e, {a, m} ->
        case MapSet.member?(m, e.resource_id) do
          true -> {a, m}
          false -> {a ++ [e], MapSet.put(m, e.resource_id)}
        end
      end)

    deduped
  end

  defp directly_locked_activities(activities, parent_pages) do
    Enum.filter(activities, fn
      %{scope: "banked"} ->
        true

      %{scope: "embedded", resource_id: resource_id} ->
        !Map.has_key?(parent_pages, resource_id)

      _ ->
        false
    end)
  end

  # For the pages that directly attach an objective, and the pages that
  # reference an activity that attaches an objective, create a unified MapSet of
  # all their resource ids
  defp unify_pages(parent_pages, pages) do
    Enum.map(parent_pages, fn {_, %{id: id}} -> id end)
    |> MapSet.new()
    |> MapSet.union(MapSet.new(Enum.map(pages, fn p -> p.resource_id end)))
  end

  def fetch_objective_mappings(project) do
    publication = Publishing.project_working_publication(project.slug)
    Publishing.get_objective_mappings_by_publication(publication.id)
  end
end
