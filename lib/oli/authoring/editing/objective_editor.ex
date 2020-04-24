defmodule Oli.Authoring.Editing.ObjectiveEditor do

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Publishing
  alias Oli.Publishing.ObjectiveMappingTransfer
  alias Oli.Publishing
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Repo

  import Oli.Utils


  def add_new(attrs, %Author{} = author, %Project{} = project, container_slug \\ nil) do

    attrs = Map.merge(attrs, %{
      author_id: author.id,
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective")
    })

    Repo.transaction(fn ->

      with {:ok, %{resource: resource, revision: revision}} <- Oli.Authoring.Course.create_and_attach_resource(project, attrs),
          publication <- Publishing.get_unpublished_publication_by_slug!(project.slug),
          {:ok, mapping} <- Publishing.upsert_published_resource(publication, revision),
          {:ok, container} <- maybe_append_to_container(container_slug, publication, revision, author)
      do
        {:ok,
          %{
            resource: resource,
            revision: revision,
            project: project,
            mapping: mapping,
            container: container
          }
        }
      else
        error -> Repo.rollback(error)
      end

    end)
  end

  def edit(revision_slug, attrs, %Author{} = author, %Project{} = project) do

    attrs = Map.merge(attrs, %{
      author_id: author.id,
    })

    Repo.transaction(fn ->

      with {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
          publication <- Publishing.get_unpublished_publication_by_slug!(project.slug),
          {:ok, revision} <- Publishing.get_published_revision(publication.id, resource.id) |> trap_nil(),
          {:ok, new_revision} <- Resources.create_revision_from_previous(revision, attrs),
          {:ok, _} <- Publishing.upsert_published_resource(publication, new_revision)
      do
        {:ok, new_revision}
      else
        error -> Repo.rollback(error)
      end

    end)
  end

  def maybe_append_to_container(container_slug, publication, revision_to_attach, author) do

    case container_slug do
      nil -> {:ok, nil}
      "" -> {:ok, nil}
      slug -> append_to_container(slug, publication, revision_to_attach, author)
    end

  end


  def append_to_container(container_slug, publication, revision_to_attach, author) do

    with {:ok, resource} <- Resources.get_resource_from_slug(container_slug) |> trap_nil(),
        {:ok, revision} <- Publishing.get_published_revision(publication.id, resource.id) |> trap_nil()
    do

      attrs = %{
        children: [revision_to_attach.resource_id | revision.children],
        author_id: author.id
      }
      {:ok, next} = Oli.Resources.create_revision_from_previous(revision, attrs)
      {:ok, _} = Publishing.upsert_published_resource(publication, next)

      {:ok, next}
    else
      error -> error
    end

  end

  def fetch_objective_mappings_params(project) do

    publication = Publishing.get_unpublished_publication(project.slug)
    objective_mappings = Publishing.get_objective_mappings_by_publication(publication.id)
    changeset = Oli.Resources.change_revision(%Oli.Resources.Revision{})

    if Enum.empty?(objective_mappings) do
      %{title: "Objectives", objective_mappings: [], objective_changeset: changeset, active: :objectives}
    else
      # Extract all children references from objectives
      children_list = objective_mappings
        |> Enum.map(fn mapping -> mapping.revision.children end)
        |> Enum.reduce(fn(children, acc) -> children ++ acc end)

      # Filter out parent mappings (i.e. objective is a parent if not in children list)
      parents = Enum.reduce(objective_mappings, [], fn(mapping, acc) ->
        if Enum.member?(children_list, mapping.revision.id) do
          acc
        else
          [mapping] ++ acc
        end
      end)

      # Build parent/children tree structure
      parents = parents |> Enum.reduce([], fn(x, acc) ->
        children = objective_mappings |>  Enum.reduce([], fn(mapping, mapping_acc) ->
          if Enum.member?(x.revision.children, mapping.revision.id) do
            [mapping] ++ mapping_acc
          else
            mapping_acc
          end
        end)
        [%ObjectiveMappingTransfer{mapping: x, children: children}] ++ acc
      end)

      %{title: "Objectives", objective_mappings: parents, objective_changeset: changeset, active: :objectives}
    end
  end



end

