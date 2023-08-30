defmodule Oli.Interop.Export do
  alias Oli.Publishing
  alias Oli.Resources.ResourceType
  alias Oli.Activities
  alias Oli.Authoring.MediaLibrary
  alias Oli.Authoring.MediaLibrary.ItemOptions
  alias Oli.Utils

  @doc """
  Generates a course digest for an existing course project.
  """
  def export(project) do
    publication = Publishing.project_working_publication(project.slug)
    resources = fetch_all_resources(publication)

    ([
       create_project_file(project),
       create_media_manifest_file(project),
       create_hierarchy_file(resources, publication)
     ] ++
       tags(resources) ++
       objectives(resources) ++
       activities(resources, project) ++
       bib_entries(resources) ++
       alternatives(resources) ++
       pages(resources, project))
    |> Utils.zip("export.zip")
  end

  defp tags(resources) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.get_id_by_type("tag")
    end)
    |> Enum.map(fn r ->
      %{
        type: "Tag",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: [],
        unresolvedReferences: [],
        content: %{},
        objectives: [],
        children: []
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  # create entries for all objectives
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
        tags: transform_tags(r),
        unresolvedReferences: [],
        content: %{},
        objectives: Enum.map(r.children, fn id -> "#{id}" end),
        children: []
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  # create entries for all activities
  defp activities(resources, project) do
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
        tags: transform_tags(r),
        unresolvedReferences: [],
        scope: r.scope,
        content: rewire_activity_content(r.content, project),
        objectives: to_string_ids(r.objectives),
        subType: Map.get(registrations, r.activity_type_id).slug
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  # convert an attached collection of objective id references to be string based
  defp to_string_ids(attached_objectives) do
    Map.keys(attached_objectives)
    |> Enum.reduce(%{}, fn part_id, m ->
      Map.put(m, part_id, Enum.map(attached_objectives[part_id], fn id -> "#{id}" end))
    end)
  end

  defp rewire_activity_elements(nil, _), do: nil

  defp rewire_activity_elements(content_as_list, project) when is_map(content_as_list) do
    case Map.get(content_as_list, "content") do
      list when is_list(list) ->
        adjusted_content = %{"type" => "content", "children" => list}
        {results, _} = rewire_elements(adjusted_content, project)
        Map.put(content_as_list, "content", results["children"])

      map when is_map(map) ->
        list = map["model"]
        adjusted_content = %{"type" => "content", "children" => list}
        {results, _} = rewire_elements(adjusted_content, project)
        content = Map.put(map, "model", results["children"])
        Map.put(content_as_list, "content", content)
    end
  end

  defp rewire_activity_elements(other, _), do: other

  defp rewire_elements(content, project) do
    Oli.Resources.PageContent.visit_children(content, {:ok, []}, fn c,
                                                                    {status, []},
                                                                    _tr_context ->
      case Map.get(c, "type") do
        "cite" ->
          {Map.put(c, "bibref", "#{Map.get(c, "bibref")}"), {status, []}}

        "page_link" ->
          {Map.put(c, "idref", "#{Map.get(c, "idref")}"), {status, []}}

        "a" ->
          case Map.get(c, "href") do
            "/course/link/" <> slug ->
              case Oli.Publishing.AuthoringResolver.from_revision_slug(project.slug, slug) do
                nil ->
                  {c, {status, []}}

                %Oli.Resources.Revision{resource_id: resource_id} ->
                  {Map.put(c, "idref", "#{resource_id}"), {status, []}}
              end

            _ ->
              {c, {status, []}}
          end

        _ ->
          {c, {status, []}}
      end
    end)
  end

  # For an activity, rewire all of the standard "content" locations:
  # stem, choices, explanation, hints, feedback.  This will take care of
  # re-wiring all of the links to pages and any bib citations.
  defp rewire_activity_content(content, project) do
    content =
      case Map.get(content, "stem") do
        nil -> content
        stem -> Map.put(content, "stem", rewire_activity_elements(stem, project))
      end

    content =
      case Map.get(content, "choices") do
        nil ->
          content

        choices ->
          choices =
            Enum.map(choices, fn choice ->
              rewire_activity_elements(choice, project)
            end)

          Map.put(content, "choices", choices)
      end

    if Map.has_key?(content, "authoring") and Map.has_key?(Map.get(content, "authoring"), "parts") do
      parts =
        content["authoring"]["parts"]
        |> Enum.map(fn part ->
          part =
            if Map.has_key?(part, "explanation") do
              Map.put(part, "explanation", rewire_activity_elements(part["explanation"], project))
            else
              part
            end

          part =
            if Map.has_key?(part, "hints") and Map.get(part, "hints") != nil do
              hints =
                Enum.map(part["hints"], fn hint ->
                  rewire_activity_elements(hint, project)
                end)

              Map.put(part, "hints", hints)
            else
              part
            end

          if Map.has_key?(part, "responses") and Map.get(part, "responses") != nil do
            responses =
              Enum.map(part["responses"], fn response ->
                if Map.has_key?(response, "feedback") do
                  Map.put(
                    response,
                    "feedback",
                    rewire_activity_elements(response["feedback"], project)
                  )
                else
                  response
                end
              end)

            Map.put(part, "responses", responses)
          else
            part
          end
        end)

      Map.put(content, "authoring", Map.put(content["authoring"], "parts", parts))
    else
      content
    end
  end

  def rewire(content, project) do
    {content, _} =
      Oli.Resources.PageContent.map_reduce(content, {:ok, []}, fn e, {status, []}, _tr_context ->
        case e do
          %{"type" => "content"} = ref ->
            rewire_elements(ref, project)

          %{"type" => "alternatives"} = ref ->
            {Map.put(ref, "group", "#{Map.get(ref, "alternatives_id")}"), {status, []}}

          other ->
            {other, {status, []}}
        end
      end)

    case Map.get(content, "bibrefs", []) do
      [] -> content
      integer_ids -> Map.put(content, "bibrefs", Enum.map(integer_ids, fn id -> "#{id}" end))
    end
  end

  # create entries for all pages
  defp pages(resources, project) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.get_id_by_type("page")
    end)
    |> Enum.map(fn r ->
      %{
        type: "Page",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: transform_tags(r),
        unresolvedReferences: [],
        content: rewire(r.content, project),
        objectives: Map.get(r.objectives, "attached", []) |> Enum.map(fn id -> "#{id}" end),
        isGraded: r.graded,
        purpose: r.purpose,
        relatesTo: r.relates_to |> Enum.map(fn id -> "#{id}" end),
        collabSpace: r.collab_space_config
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  defp bib_entries(resources) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.get_id_by_type("bibentry")
    end)
    |> Enum.map(fn r ->
      %{
        type: "Bibentry",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: transform_tags(r),
        unresolvedReferences: [],
        content: r.content,
        objectives: []
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  defp alternatives(resources) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.get_id_by_type("alternatives")
    end)
    |> Enum.map(fn r ->
      %{
        type: "Alternatives",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: transform_tags(r),
        unresolvedReferences: [],
        content: r.content,
        objectives: []
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  # retrieve all resource revisions for this publication
  defp fetch_all_resources(publication) do
    Publishing.get_published_resources_by_publication(publication.id)
    |> Enum.filter(fn mapping -> mapping.revision.deleted == false end)
    |> Enum.map(fn mapping -> mapping.revision end)
  end

  # create the _project.json file
  defp create_project_file(project) do
    %{
      title: project.title,
      description: project.description,
      type: "Manifest",
      required_student_survey: project.required_survey_resource_id
    }
    |> entry("_project.json")
  end

  # create the media manifest file
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

  # create the singular hierarchy file
  defp create_hierarchy_file(resources, publication) do
    revisions_by_id = Enum.reduce(resources, %{}, fn r, m -> Map.put(m, r.resource_id, r) end)
    root = Map.get(revisions_by_id, publication.root_resource_id)

    %{
      type: "Hierarchy",
      id: "",
      originalFile: "",
      title: "",
      tags: transform_tags(root),
      children: Enum.map(root.children, fn id -> full_hierarchy(revisions_by_id, id) end)
    }
    |> entry("_hierarchy.json")
  end

  # helper to create a zip entry tuple
  defp entry(contents, name) do
    {String.to_charlist(name), Utils.pretty(contents)}
  end

  # recursive impl to build out the nested, digest specific representation of the course hierarchy
  defp full_hierarchy(revisions_by_id, resource_id) do
    revision = Map.get(revisions_by_id, resource_id)

    case ResourceType.get_type_by_id(revision.resource_type_id) do
      "container" ->
        %{
          type: "container",
          id: "#{resource_id}",
          title: revision.title,
          tags: transform_tags(revision),
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

  defp transform_tags(revision) do
    Enum.map(revision.tags, fn id -> Integer.to_string(id, 10) end)
  end
end
