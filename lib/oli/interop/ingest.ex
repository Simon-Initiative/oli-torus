defmodule Oli.Interop.Ingest do
  alias Oli.Repo
  alias Oli.Publishing.ChangeTracker
  alias Oli.Interop.Scrub
  alias Oli.Resources.PageContent
  alias Oli.Utils.SchemaResolver

  @project_key "_project"
  @hierarchy_key "_hierarchy"
  @media_key "_media-manifest"

  @doc """
  Ingest a course digest archive that is sitting on the file system
  and turn it into a course project.  Gives the author specified access
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
      _ -> {:error, :invalid_archive}
    end
  end

  # verify that an in memory digest is valid by ensuring that it contains the three
  # required keys (files): the "_project", the "_hierarchy" and the "_media-manifest"
  defp is_valid_digest?(map) do
    if Map.has_key?(map, @project_key) && Map.has_key?(map, @hierarchy_key) &&
         Map.has_key?(map, @media_key) do
      {:ok, map}
    else
      {:error, :invalid_digest}
    end
  end

  # Validates all idrefs in the content of the resource map.
  # Returns {:ok} if all refs are valid and {:error, [...invalid_refs]} if invalid idrefs are found.
  defp validate_idrefs(map) do
    all_id_refs =
      Enum.reduce(map, [], fn {_file, content}, acc ->
        find_all_id_refs(content) ++ acc
      end)

    invalid_idrefs =
      Enum.filter(all_id_refs, fn id_ref ->
        !Map.has_key?(map, id_ref)
      end)

    case invalid_idrefs do
      [] ->
        {:ok}

      invalid_idrefs ->
        {:error, {:invalid_idrefs, invalid_idrefs}}
    end
  end

  defp find_all_id_refs(content) do
    idrefs_recursive_desc(content, [])
  end

  defp idrefs_recursive_desc(el, idrefs) do
    # if this element contains an idref, add it to the list

    idrefs =
      case el do
        %{"idref" => idref} ->
          [idref | idrefs]

        _ ->
          idrefs
      end

    # if this element contains children, recursively process them, otherwise return the list
    case el do
      %{"children" => children} ->
        Enum.reduce(children, idrefs, fn c, acc ->
          idrefs_recursive_desc(c, acc)
        end)

      _ ->
        idrefs
    end
  end

  # Process the unzipped entries of the archive
  def process(entries, as_author) do
    {resource_map, _error_map} = to_map(entries)

    Repo.transaction(fn _ ->
      with {:ok, _} <- is_valid_digest?(resource_map),
           {:ok} <- validate_idrefs(resource_map),
           project_details <- Map.get(resource_map, @project_key),
           media_details <- Map.get(resource_map, @media_key),
           hierarchy_details <- Map.get(resource_map, @hierarchy_key),
           {:ok, %{project: project, resource_revision: root_revision}} <-
             create_project(project_details, as_author),
           {:ok, tag_map} <- create_tags(project, resource_map, as_author),
           {:ok, objective_map} <- create_objectives(project, resource_map, tag_map, as_author),
           {:ok, {activity_map, _}} <-
             create_activities(project, resource_map, objective_map, tag_map, as_author),
           {:ok, {page_map, _}} <-
             create_pages(
               project,
               resource_map,
               activity_map,
               objective_map,
               tag_map,
               as_author
             ),
           {:ok, _} <- create_media(project, media_details),
           {:ok, _} <-
             create_hierarchy(
               project,
               root_revision,
               page_map,
               tag_map,
               hierarchy_details,
               as_author
             ),
           {:ok, _} <- Oli.Ingest.RewireLinks.rewire_all_hyperlinks(page_map, project) do
        project
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  defp get_registration_map() do
    Oli.Activities.list_activity_registrations()
    |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.slug, e.id) end)
  end

  # Process the _project file to create the project structure
  defp create_project(project_details, as_author) do
    case Map.get(project_details, "title") do
      nil -> {:error, :missing_project_title}
      "" -> {:error, :empty_project_title}
      title -> Oli.Authoring.Course.create_project(title, as_author)
    end
  end

  defp create_tags(project, resource_map, as_author) do
    tags =
      Map.keys(resource_map)
      |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
      |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Tag" end)

    Repo.transaction(fn ->
      case Enum.reduce_while(tags, %{}, fn {id, tag}, map ->
             case create_tag(project, tag, as_author) do
               {:ok, revision} -> {:cont, Map.put(map, id, revision)}
               {:error, e} -> {:halt, {:error, e}}
             end
           end) do
        {:error, e} -> Repo.rollback(e)
        map -> map
      end
    end)
  end

  defp create_activities(project, resource_map, objective_map, tag_map, as_author) do
    registration_map = get_registration_map()

    {changes, activities} =
      Map.keys(resource_map)
      |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
      |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Activity" end)
      |> scrub_resources()

    Repo.transaction(fn ->
      case Enum.reduce_while(activities, %{}, fn {id, activity}, map ->
             case create_activity(
                    project,
                    activity,
                    as_author,
                    registration_map,
                    tag_map,
                    objective_map
                  ) do
               {:ok, revision} -> {:cont, Map.put(map, id, revision)}
               {:error, e} -> {:halt, {:error, e}}
             end
           end) do
        {:error, e} -> Repo.rollback(e)
        map -> {map, List.flatten(changes)}
      end
    end)
  end

  # Process each resource file of type "Page" to create pages
  defp create_pages(project, resource_map, activity_map, objective_map, tag_map, as_author) do
    {changes, pages} =
      Map.keys(resource_map)
      |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
      |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Page" end)
      |> scrub_resources()

    Repo.transaction(fn ->
      case Enum.reduce_while(pages, %{}, fn {id, page}, map ->
             case create_page(project, page, activity_map, objective_map, tag_map, as_author) do
               {:ok, revision} -> {:cont, Map.put(map, id, revision)}
               {:error, e} -> {:halt, {:error, e}}
             end
           end) do
        {:error, e} -> Repo.rollback(e)
        map -> {map, List.flatten(changes)}
      end
    end)
  end

  defp scrub_resources(resources) do
    Enum.map(resources, fn {id, %{"content" => content, "title" => title} = resource} ->
      case Scrub.scrub(content) do
        {[], _} ->
          {[], {id, resource}}

        {changes, changed} ->
          {Enum.map(changes, fn c -> "#{title}: #{c}" end),
           {id, Map.put(resource, "content", changed)}}
      end
    end)
    |> Enum.unzip()
  end

  defp create_objectives(project, resource_map, tag_map, as_author) do
    objectives =
      Map.keys(resource_map)
      |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
      |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Objective" end)

    with_children =
      Enum.filter(objectives, fn {_, o} -> Map.get(o, "objectives", []) |> Enum.count() > 0 end)

    without_children =
      Enum.filter(objectives, fn {_, o} -> Map.get(o, "objectives", []) |> Enum.count() == 0 end)

    Repo.transaction(fn ->
      case Enum.reduce_while(without_children ++ with_children, %{}, fn {id, o}, map ->
             case create_objective(project, o, tag_map, as_author, map) do
               {:ok, revision} -> {:cont, Map.put(map, id, revision)}
               {:error, e} -> {:halt, {:error, e}}
             end
           end) do
        {:error, e} -> Repo.rollback(e)
        map -> map
      end
    end)
  end

  # import / export can lead to situations where we need to consider first the key
  # as an integer, and secondly the key as a string
  defp retrieve(map, key) do
    case Map.get(map, key) do
      nil ->
        Map.get(map, Integer.to_string(key, 10))

      m ->
        m
    end
  end

  defp rewire_activity_references(content, activity_map) do
    PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs} ->
      case e do
        %{"type" => "activity-reference", "activity_id" => original} = ref ->
          case retrieve(activity_map, original) do
            nil ->
              {ref, {:error, [original | invalid_refs]}}

            retrieved ->
              {Map.put(ref, "activity_id", retrieved.resource_id), {status, invalid_refs}}
          end

        other ->
          {other, {status, invalid_refs}}
      end
    end)
    |> case do
      {mapped, {:ok, _}} ->
        {:ok, mapped}

      {_mapped, {:error, invalid_refs}} ->
        {:error, {:rewire_activity_references, invalid_refs}}
    end
  end

  defp rewire_bank_selections(content, tag_map) do
    PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs} ->
      case e do
        %{"type" => "selection", "logic" => logic} = ref ->
          case logic do
            %{"conditions" => %{"children" => [%{"fact" => "tags", "value" => originals}]}} ->
              Enum.reduce(originals, {[], {:ok, []}}, fn o, {ids, {status, invalid_ids}} ->
                case retrieve(tag_map, o) do
                  nil ->
                    {ids, {:error, [o | invalid_ids]}}

                  retrieved ->
                    {[retrieved.resource_id | ids], {status, invalid_ids}}
                end
              end)
              |> case do
                {ids, {:ok, _}} ->
                  children = [%{"fact" => "tags", "value" => ids, "operator" => "equals"}]
                  conditions = Map.put(logic["conditions"], "children", children)
                  logic = Map.put(logic, "conditions", conditions)

                  {Map.put(ref, "logic", logic), {status, invalid_refs}}

                {_, {:error, invalid_ids}} ->
                  {ref, {status, invalid_ids ++ invalid_refs}}
              end

            _ ->
              {ref, {status, invalid_refs}}
          end

        other ->
          {other, {status, invalid_refs}}
      end
    end)
    |> case do
      {mapped, {:ok, _}} ->
        {:ok, mapped}

      {_mapped, {:error, invalid_refs}} ->
        {:error, {:rewire_bank_selections, invalid_refs}}
    end
  end

  # Create one page
  defp create_page(project, page, activity_map, objective_map, tag_map, as_author) do
    with content <- Map.get(page, "content"),
         :ok <- validate_json(content, SchemaResolver.schema("page-content.schema.json")),
         {:ok, content} <- rewire_activity_references(content, activity_map),
         {:ok, content} <- rewire_bank_selections(content, tag_map) do
      graded = Map.get(page, "isGraded", false)

      %{
        tags: transform_tags(page, tag_map),
        title: Map.get(page, "title"),
        content: content,
        author_id: as_author.id,
        objectives: %{
          "attached" =>
            Enum.map(page["objectives"], fn id ->
              case Map.get(objective_map, id) do
                nil -> nil
                r -> r.resource_id
              end
            end)
            |> Enum.filter(fn f -> !is_nil(f) end)
        },
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        graded: graded,
        max_attempts:
          if graded do
            5
          else
            0
          end
      }
      |> create_resource(project)
    end
  end

  defp validate_json(json, schema) do
    case ExJsonSchema.Validator.validate(schema, json) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error, {:invalid_json, schema, errors, json}}
    end
  end

  defp create_activity(
         project,
         activity,
         as_author,
         registration_by_subtype,
         tag_map,
         objective_map
       ) do
    with :ok <- validate_json(activity, SchemaResolver.schema("activity.schema.json")) do

      title =
        case Map.get(activity, "title") do
          nil -> Map.get(activity, "subType")
          "" -> Map.get(activity, "subType")
          title -> title
        end

      scope =
        case Map.get(activity, "scope", "embedded") do
          str when str in ~w(embedded banked) -> String.to_existing_atom(str)
          _ -> :embedded
        end

      %{
        scope: scope,
        tags: transform_tags(activity, tag_map),
        title: title,
        content: Map.get(activity, "content"),
        author_id: as_author.id,
        objectives: process_activity_objectives(activity, objective_map),
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
        activity_type_id: Map.get(registration_by_subtype, Map.get(activity, "subType")),
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average")
      }
      |> create_resource(project)
    end
  end

  defp process_activity_objectives(activity, objective_map) do
    case Map.get(activity, "objectives", []) do
      map when is_map(map) ->
        Map.keys(map)
        |> Enum.reduce(%{}, fn k, m ->
          mapped =
            Map.get(activity, "objectives")[k]
            |> Enum.map(fn id -> Map.get(objective_map, id).resource_id end)

          Map.put(m, k, mapped)
        end)

      list when is_list(list) ->
        activity["content"]["authoring"]["parts"]
        |> Enum.map(fn %{"id" => id} -> id end)
        |> Enum.reduce(%{}, fn e, m ->
          objectives = Enum.map(list, fn id -> Map.get(objective_map, id).resource_id end)
          Map.put(m, e, objectives)
        end)
    end
  end

  defp create_tag(project, tag, as_author) do
    %{
      tags: [],
      title: Map.get(tag, "title", "empty tag"),
      content: %{},
      author_id: as_author.id,
      objectives: %{},
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("tag")
    }
    |> create_resource(project)
  end

  defp create_objective(project, objective, tag_map, as_author, objective_map) do
    title =
      case Map.get(objective, "title") do
        nil -> "Empty"
        "" -> "Empty"
        title -> title
      end

    %{
      tags: transform_tags(objective, tag_map),
      title: title,
      content: %{},
      author_id: as_author.id,
      objectives: %{},
      children:
        Map.get(objective, "objectives", [])
        |> Enum.map(fn id -> Map.get(objective_map, id).resource_id end),
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective")
    }
    |> create_resource(project)
  end

  defp create_resource(attrs, project) do
    with {:ok, %{revision: revision}} <-
           Oli.Authoring.Course.create_and_attach_resource(project, attrs),
         {:ok, _} <- ChangeTracker.track_revision(project.slug, revision) do
      {:ok, revision}
    else
      {:error, e} -> {:error, e}
    end
  end

  # Create the media entries
  defp create_media(project, media_details) do
    items =
      Map.get(media_details, "mediaItems")
      |> Enum.map(fn i ->
        %{
          url: i["url"],
          file_name: i["name"],
          mime_type: i["mimeType"],
          file_size: i["fileSize"],
          md5_hash: i["md5"],
          deleted: false,
          project_id: project.id
        }
      end)

    Repo.transaction(fn -> Enum.map(items, &Oli.Authoring.MediaLibrary.create_media_item/1) end)
  end

  # create the course hierarchy
  defp create_hierarchy(project, root_revision, page_map, tag_map, hierarchy_details, as_author) do
    # Process top-level items and containers, add recursively add containers
    children =
      Map.get(hierarchy_details, "children")
      |> Enum.filter(fn c -> c["type"] == "item" || c["type"] == "container" end)
      |> Enum.map(fn c ->
        case Map.get(c, "type") do
          "item" -> Map.get(page_map, Map.get(c, "idref")).resource_id
          "container" -> create_container(project, page_map, as_author, tag_map, c)
        end
      end)

    # wire those newly created top-level containers into the root resource
    ChangeTracker.track_revision(project.slug, root_revision, %{children: children})
  end

  # This is the recursive container creation routine.  It processes a hierarchy by
  # descending through the tree and processing the leaves first, and then back upwards.
  defp create_container(project, page_map, as_author, tag_map, container) do
    # recursively visit item container in the hierarchy, and via bottom
    # up approach create resource and revisions for each container, while
    # substituting page references for resource ids and container references
    # for container resource ids

    children_ids =
      Map.get(container, "children")
      |> Enum.map(fn c ->
        case Map.get(c, "type") do
          "item" -> Map.get(page_map, Map.get(c, "idref")).resource_id
          "container" -> create_container(project, page_map, as_author, tag_map, c)
        end
      end)

    attrs = %{
      tags: transform_tags(container, tag_map),
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

  defp transform_tags(value, tag_map) do
    Map.get(value, "tags", [])
    |> Enum.map(fn id ->
      case Map.get(tag_map, id) do
        nil -> nil
        rev -> rev.resource_id
      end
    end)
    |> Enum.filter(fn id -> !is_nil(id) end)
  end

  # Convert the list of tuples of unzipped entries into a map
  # where the keys are the ids (with the .json extension dropped)
  # and the values are the JSON content, parsed into maps
  def to_map(entries) do
    Enum.reduce(entries, {%{}, %{}}, fn {file, content}, {resource_map, error_map} ->
      id_from_file = fn file ->
        file
        |> List.to_string()
        |> :filename.basename()
        |> String.replace_suffix(".json", "")
      end

      case Poison.decode(content) do
        {:ok, decoded} ->
          # Take the id from the attribute within the file content, unless
          # that id is not present (nil) or empty string. In that case,
          # use the file name to determine the id.  This allows us to avoid
          # issues of ids that contain unicode characters not being parsed
          # correctly from zip file entries.
          id =
            case Map.get(decoded, "id") do
              nil -> id_from_file.(file)
              "" -> id_from_file.(file)
              id -> id
            end

          {Map.put(resource_map, id, decoded), error_map}

        _ ->
          {resource_map,
           Map.put(
             error_map,
             id_from_file.(file),
             "failed to decode file '#{id_from_file.(file)}'"
           )}
      end
    end)
  end

  def prettify_error({:error, :invalid_archive}) do
    "Project archive is invalid. Archive must be a valid zip file"
  end

  def prettify_error({:error, :invalid_digest}) do
    "Project archive is invalid. Archive must include #{@project_key}.json, #{@hierarchy_key}.json and #{@media_key}.json"
  end

  def prettify_error({:error, :missing_project_title}) do
    "Project title not found in #{@project_key}.json"
  end

  def prettify_error({:error, :empty_project_title}) do
    "Project title cannot be empty in #{@project_key}.json"
  end

  def prettify_error({:error, {:invalid_idrefs, invalid_idrefs}}) do
    invalid_idrefs_str = Enum.join(invalid_idrefs, ", ")

    case Enum.count(invalid_idrefs) do
      1 ->
        "Project contains an invalid idref reference: #{invalid_idrefs_str}"

      count ->
        "Project contains #{count} invalid idref references: #{invalid_idrefs_str}"
    end
  end

  def prettify_error({:error, {:rewire_activity_references, invalid_refs}}) do
    invalid_refs_str = Enum.join(invalid_refs, ", ")

    case Enum.count(invalid_refs) do
      1 ->
        "Project contains an invalid activity reference: #{invalid_refs_str}"

      count ->
        "Project contains #{count} invalid activity references: #{invalid_refs_str}"
    end
  end

  def prettify_error({:error, {:rewire_bank_selections, invalid_refs}}) do
    invalid_refs_str = Enum.join(invalid_refs, ", ")

    case Enum.count(invalid_refs) do
      1 ->
        "Project contains an invalid activity bank selection reference: #{invalid_refs_str}"

      count ->
        "Project contains #{count} invalid activity bank selection references: #{invalid_refs_str}"
    end
  end

  def prettify_error({:error, {:invalid_json, schema, _errors, json}}) do
    "Invalid JSON found in '#{json["id"]}' according to schema #{schema.schema["$id"]}"
  end

  def prettify_error({:error, error}) do
    "An unknown error occurred: #{Kernel.to_string(error)}"
  end
end
