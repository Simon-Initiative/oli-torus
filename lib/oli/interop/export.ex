defmodule Oli.Interop.Export do
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ResourceType
  alias Oli.Activities
  alias Oli.Authoring.MediaLibrary
  alias Oli.Authoring.MediaLibrary.ItemOptions

  @doc """
  Generates a course digest for an existing course project.
  """
  def export(project) do
    publication = AuthoringResolver.publication(project.slug)
    resources = fetch_all_resources(publication)

    ([
       create_project_file(project),
       create_media_manifest_file(project),
       create_hierarchy_file(resources, publication)
     ] ++
       objectives(resources) ++
       activities(resources) ++
       pages(resources))
    |> zip
  end

  defp zip(filename_content_tuples) do
    {:ok, {_filename, data}} =
      :zip.create(
        "export.zip",
        filename_content_tuples,
        [:memory]
      )

    data
  end

  defp objectives(resources) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.get_id_by_type("objective")
    end)
    |> Enum.map(fn r ->
      %{
        type: "Objective",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: [],
        unresolvedReferences: [],
        content: %{},
        objectives: [],
        children: Enum.map(r.children, fn id -> "#{id}" end)
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  defp activities(resources) do
    registrations =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.id, r) end)

    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.get_id_by_type("activity")
    end)
    |> Enum.map(fn r ->
      %{
        type: "Activity",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: [],
        unresolvedReferences: [],
        content: r.content,
        objectives: to_string_ids(r.objectives),
        subType: Map.get(registrations, r.activity_type_id).slug
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  defp to_string_ids(attached_objectives) do
    Map.keys(attached_objectives)
    |> Enum.reduce(%{}, fn part_id, m ->
      Map.put(m, part_id, Enum.map(attached_objectives[part_id], fn id -> "#{id}" end))
    end)
  end

  defp pages(resources) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.get_id_by_type("page")
    end)
    |> Enum.map(fn r ->
      %{
        type: "Page",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: [],
        unresolvedReferences: [],
        content: r.content,
        objectives: Map.get(r.objectives, "attached", []) |> Enum.map(fn id -> "#{id}" end),
        isGraded: r.graded
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  defp fetch_all_resources(publication) do
    Publishing.get_published_resources_by_publication(publication.id)
    |> Enum.filter(fn mapping -> mapping.revision.deleted == false end)
    |> Enum.map(fn mapping -> mapping.revision end)
  end

  defp create_project_file(project) do
    %{
      title: project.title,
      description: project.description,
      type: "Manifest"
    }
    |> entry("_project.json")
  end

  defp create_media_manifest_file(project) do
    {:ok, {items, _}} =
      MediaLibrary.items(project.slug, Map.merge(ItemOptions.default(), %{limit: nil}))

    mediaItems =
      Enum.map(items, fn item ->
        %{
          name: item.file_name,
          file: "",
          url: item.url,
          fileSize: item.file_size,
          mimeType: item.mime_type,
          md5: item.md5_hash
        }
      end)

    %{
      mediaItems: mediaItems,
      type: "MediaManifest"
    }
    |> entry("_media-manifest.json")
  end

  defp create_hierarchy_file(resources, publication) do
    revisions_by_id = Enum.reduce(resources, %{}, fn r, m -> Map.put(m, r.resource_id, r) end)
    root = Map.get(revisions_by_id, publication.root_resource_id)

    %{
      type: "Hierarchy",
      id: "",
      originalFile: "",
      title: "",
      tags: [],
      children: Enum.map(root.children, fn id -> full_hierarchy(revisions_by_id, id) end)
    }
    |> entry("_hierarchy.json")
  end

  defp entry(contents, name) do
    {String.to_charlist(name), pretty(contents)}
  end

  defp pretty(map) do
    Jason.encode_to_iodata!(map)
    |> Jason.Formatter.pretty_print()
  end

  def full_hierarchy(revisions_by_id, resource_id) do
    revision = Map.get(revisions_by_id, resource_id)

    case ResourceType.get_type_by_id(revision.resource_type_id) do
      "container" ->
        %{
          type: "container",
          id: "#{resource_id}",
          title: revision.title,
          children: Enum.map(revision.children, fn id -> full_hierarchy(revisions_by_id, id) end)
        }

      "page" ->
        %{
          type: "item",
          children: [],
          idref: "#{resource_id}"
        }
    end
  end
end
