defmodule Oli.Authoring.Ingest do

  alias Oli.Repo
  alias Oli.Publishing.ChangeTracker

  @project_key "_project"
  @hierarchy_key "_hierarchy"
  @media_key "_media-manifest"

  @doc """
  Ingest a course digest archive that is sitting on the file system
  and turn it into a course project.  Gives the author specied access
  to the new project.

  A course digest archive is a zip file containing a flat list of JSON files.

  There are three required files in a course archive:

  _project.json: a document containing top-level project meta data
  _hierarchy.json: a document that specifies the course project container hierarchy
  _media-manifest.json: a manifest listing all of the media items referenced by the digest

  Any number of other JSON files corresponding to pages and activities can exist
  in the digest archive.

  Returns {:ok, project} on success and {:error, error} on failure
  """
  def ingest(file, as_author) do

    case :zip.unzip(to_charlist(file), [:memory]) do
      {:ok, entries} -> process(entries, as_author)
      _ -> {:error, "error processing archive file"}
    end

  end

  # verify that an in memory archive is valid by ensuring that it contains the three
  # required keys (files): the "_project", the "_hierarchy" and the "_media-manifest"
  defp is_valid_archive?(map) do
    Map.has_key?(map, @project_key) && Map.has_key?(map, @hierarchy_key) && Map.has_key?(map, @media_key)
  end

  # Process the unzipped entries of the archive
  defp process(entries, as_author) do

    resource_map = to_map(entries)

    # Proceed only if the archive is valid
    if is_valid_archive?(resource_map) do

      Repo.transaction(fn _ ->

        project_details = Map.get(resource_map, @project_key)
        media_details = Map.get(resource_map, @media_key)
        hierarchy_details = Map.get(resource_map, @hierarchy_key)

        with {:ok, %{project: project, resource_revision: root_revision}} <- create_project(project_details, as_author),
          {:ok, page_map} <- create_pages(project, resource_map, as_author),
          {:ok, _} <- create_media(project, media_details, as_author),
          {:ok, _} <- create_hierarchy(project, root_revision, page_map, hierarchy_details, as_author)
        do
          project
        else
          error -> Repo.rollback(error)
        end

      end)
    else
      {:error, "invalid archive"}
    end
  end

  # Process the _project file to create the project structure
  defp create_project(project_details, as_author) do

    case Map.get(project_details, "title") do
      nil -> {:error, "no project title found"}
      title -> Oli.Authoring.Course.create_project(title, as_author)
    end

  end

  # Process each resource file of type "Page" to create pages
  defp create_pages(project, resource_map, as_author) do

    pages = Map.keys(resource_map)
    |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
    |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Page" end)

    Repo.transaction(fn ->

      case Enum.reduce_while(pages, %{}, fn {id, page}, map ->

        case create_page(project, page, as_author) do
          {:ok, revision} -> {:cont, Map.put(map, id, revision)}
          {:error, e} -> {:halt, {:error, e}}
        end

      end) do

        {:error, e} -> Repo.rollback(e)
        map -> map
      end

    end)

  end

  # Create one page
  defp create_page(project, page, as_author) do

    attrs = %{
      title: Map.get(page, "title"),
      content: Map.get(page, "content"),
      author_id: as_author.id,
      objectives: %{"attached" => []},
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
      graded: false
    }

    with {:ok, %{revision: revision}} <- Oli.Authoring.Course.create_and_attach_resource(project, attrs),
          {:ok, _} <- ChangeTracker.track_revision(project.slug, revision)
    do
      {:ok, revision}
    else
      {:error, e} -> {:error, e}
    end

  end

  # Create the media entries
  defp create_media(_project, _media_details, _as_author) do
    {:ok, %{}}
  end

  # create the course hierarchy
  defp create_hierarchy(project, root_revision, page_map, hierarchy_details, as_author) do

    # filter for the top-level containers, add recursively add them
    children = Map.get(hierarchy_details, "children")
    |> Enum.filter(fn c -> Map.get(c, "type") == "container" end)
    |> Enum.map(fn c -> create_container(project, page_map, as_author, c) end)

    # wire those newly created top-level containers into the root resource
    ChangeTracker.track_revision(project.slug, root_revision, %{children: children})

  end

  # This is the recursive container creation routine.  It processes a hierarchy by
  # descending through the tree and processing the leaves first, and then back upwards.
  defp create_container(project, page_map, as_author, container) do


    # recursively visit item container in the hierarchy, and via bottom
    # up approach create resource and revisions for each container, while
    # substituting page references for resource ids and container references
    # for container resource ids

    children_ids = Map.get(container, "children")
    |> Enum.map(fn c ->

      case Map.get(c, "type") do
        "item" -> Map.get(page_map, Map.get(c, "idref")).resource_id
        "container" -> create_container(project, page_map, as_author, c)
      end

    end)

    attrs = %{
      title: Map.get(container, "title"),
      children: children_ids,
      author_id: as_author.id,
      content: %{"model" => []},
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
    }

    {:ok, %{revision: revision}} = Oli.Authoring.Course.create_and_attach_resource(project, attrs)
    {:ok, _} = ChangeTracker.track_revision(project.slug, revision)
    revision.resource_id

  end

  # Convert the list of tuples of unzipped entries into a map
  # where the keys are the ids (with the .json extension dropped)
  # and the values are the JSON content, parsed into maps
  defp to_map(entries) do

    Enum.reduce(entries, %{}, fn {file, content}, map ->

      f = List.to_string(file)
      id = String.slice(f, 0, String.length(f) - 5)

      Map.put(map, id, Poison.decode!(content))
    end)

  end

end
