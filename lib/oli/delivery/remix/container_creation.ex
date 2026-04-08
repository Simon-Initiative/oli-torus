defmodule Oli.Delivery.Remix.ContainerCreation do
  @moduledoc """
  Service module for creating containers in the template remix context.

  Two-phase approach:
  - `build_draft/4`: Creates an in-memory HierarchyNode with a deterministic negative ID.
    No database writes. The draft is purely in-memory until save.
  - `materialize/3`: Called at save time. Walks the hierarchy, finds draft nodes
    (resource_id < 0), creates real Resource + Revision + PublishedResources in a single
    transaction, and swaps the negative IDs for real ones.

  Cancel = zero DB trace. The draft nodes are garbage collected with the in-memory state.
  """

  import Ecto.Query

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Numbering
  alias Oli.Branding.CustomLabels
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Publishing

  @doc """
  Generates a title for a new container based on the active node's level and existing children.

  Uses `Numbering.container_type_label/1` for the label (e.g., "Unit", "Module", "Section")
  and appends a sequential number if containers already exist at that level.
  """
  def generate_title(active) do
    %Numbering{} = numbering = active.numbering
    label = Numbering.container_type_label(%{numbering | level: numbering.level + 1})

    existing_containers =
      Enum.count(active.children, fn child ->
        child.revision.resource_type_id == ResourceType.id_for_container()
      end)

    "#{label} #{existing_containers + 1}"
  end

  @doc """
  Builds an in-memory HierarchyNode with a deterministic negative resource_id.
  No database writes occur.

  The negative ID is derived from the current hierarchy: `min(smallest_existing_id, 0) - 1`.
  This produces sequential IDs (-1, -2, -3, ...) that are predictable and easy to debug.

  ## Options
    - `:container_scope` - defaults to `:blueprint`. Use `:section` for instructor remix (future).
  """
  def build_draft(hierarchy, project, title, opts \\ []) do
    container_scope = Keyword.get(opts, :container_scope, :blueprint)
    next_id = next_negative_id(hierarchy)

    draft_revision = %Revision{
      id: next_id,
      resource_id: next_id,
      resource_type_id: ResourceType.id_for_container(),
      container_scope: container_scope,
      title: title,
      children: [],
      content: %{"model" => [], "version" => "0.1.0"},
      deleted: false,
      slug: "draft-container-#{abs(next_id)}"
    }

    %HierarchyNode{
      uuid: Oli.Utils.uuid(),
      resource_id: next_id,
      numbering: %Numbering{index: 0, level: 0, labels: CustomLabels.default_map()},
      revision: draft_revision,
      project_id: project.id,
      children: [],
      section_resource: nil,
      finalized: false
    }
  end

  @doc """
  Materializes all draft nodes in the hierarchy to real database records.

  Finds nodes with `resource_id < 0`, creates Resource + Revision + PublishedResources
  for each in a single transaction, and swaps the negative IDs for real ones.

  Author can be nil for instructor remix saves — instructors can rearrange, add materials,
  and remove items but cannot create containers (no Create button on enrollable sections).
  Their saves have no draft nodes, so author is never needed.
  If author is nil but drafts somehow exist, returns `{:error, :author_required_for_materialization}`.

  Returns `{:ok, materialized_hierarchy}` or `{:error, reason}`.
  """
  @spec materialize(HierarchyNode.t(), map(), Author.t() | nil) ::
          {:ok, HierarchyNode.t()} | {:error, term()}
  def materialize(hierarchy, _project, _author = nil) do
    if Enum.empty?(find_draft_nodes(hierarchy)) do
      {:ok, hierarchy}
    else
      {:error, :author_required_for_materialization}
    end
  end

  def materialize(hierarchy, project, author) do
    draft_nodes = find_draft_nodes(hierarchy)

    if Enum.empty?(draft_nodes) do
      {:ok, hierarchy}
    else
      Repo.transaction(fn ->
        # Step 1: Create all resources, stop on first error
        result =
          Enum.reduce_while(draft_nodes, {[], []}, fn %HierarchyNode{} = draft,
                                                      {nodes, revisions} ->
            case create_draft_resource(project, draft, author) do
              {:ok, %{resource: resource, revision: revision}} ->
                node = %HierarchyNode{draft | resource_id: resource.id, revision: revision}
                {:cont, {[node | nodes], [revision | revisions]}}

              {:error, reason} ->
                {:halt, {:error, reason}}
            end
          end)

        case result do
          {:error, reason} ->
            Repo.rollback(reason)

          {updated_nodes, revisions} ->
            # Step 2: One batch insert for ALL published resources across ALL drafts
            all_publication_ids(project.id) |> batch_insert_published_resources(revisions)
            Hierarchy.find_and_update_nodes(hierarchy, Enum.reverse(updated_nodes))
        end
      end)
    end
  end

  defp find_draft_nodes(hierarchy) do
    Hierarchy.collect(hierarchy, &(&1.resource_id < 0))
  end

  defp create_draft_resource(project, draft, author) do
    attrs = %{
      title: draft.revision.title,
      resource_type_id: ResourceType.id_for_container(),
      container_scope: draft.revision.container_scope,
      # Intentionally empty — the canonical parent-child structure lives in SectionResource.children,
      # built from the in-memory hierarchy by rebuild_section_curriculum. Revision.children is only
      # used on the authoring side and blueprint containers never appear in authoring views.
      children: [],
      content: %{"model" => [], "version" => "0.1.0"},
      objectives: %{},
      graded: false,
      author_id: author.id
    }

    Course.create_and_attach_resource(project, attrs)
  end

  defp batch_insert_published_resources(publication_ids, revisions) do
    now = DateTime.utc_now(:second)

    rows =
      for revision <- revisions, pub_id <- publication_ids do
        %{
          publication_id: pub_id,
          resource_id: revision.resource_id,
          revision_id: revision.id,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(Publishing.PublishedResource, rows)
  end

  defp all_publication_ids(project_id) do
    Repo.all(
      from pub in Publishing.Publications.Publication,
        where: pub.project_id == ^project_id,
        select: pub.id
    )
  end

  defp next_negative_id(hierarchy) do
    all_ids = Enum.map(Hierarchy.flatten_hierarchy(hierarchy), & &1.resource_id)

    min(Enum.min(all_ids, fn -> 0 end), 0) - 1
  end
end
