defmodule Oli.Interop.Ingest do
  alias Oli.Repo
  alias Oli.Publishing.ChangeTracker
  alias Oli.Interop.Scrub
  alias Oli.Resources.PageContent
  alias Oli.Utils.SchemaResolver
  alias Oli.Resources.ContentMigrator
  alias Oli.Authoring.Course

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
             create_project(project_details, as_author, hierarchy_details),
           {:ok, tag_map} <- create_tags(project, resource_map, as_author),
           {:ok, objective_map} <- create_objectives(project, resource_map, tag_map, as_author),
           {:ok, bib_map} <- create_bibentries(project, resource_map, as_author),
           {:ok, {activity_map, _}} <-
             create_activities(project, resource_map, objective_map, tag_map, as_author),
           {:ok, {page_map, _}} <-
             create_pages(
               project_details,
               project,
               resource_map,
               activity_map,
               objective_map,
               tag_map,
               bib_map,
               as_author
             ),
           {:ok, _} <- create_media(project, media_details),
           {:ok, container_map} <-
             create_hierarchy(
               project,
               root_revision,
               page_map,
               tag_map,
               hierarchy_details,
               as_author
             ),
           {:ok, _} <- Oli.Ingest.RewireLinks.rewire_all_hyperlinks(page_map, project, page_map),
           {:ok, _} <-
             create_products(
               project,
               root_revision,
               resource_map,
               page_map,
               container_map,
               as_author
             ) do
        project
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  # Create any products that are found in the digest.
  defp create_products(project, root_revision, resource_map, page_map, container_map, as_author) do
    products =
      Map.keys(resource_map)
      |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
      |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Product" end)

    case products do
      [] ->
        {:ok, container_map}

      _ ->
        # Products can only be created with the project published, so do that first
        Oli.Publishing.publish_project(project, "Initial publication", as_author.id)

        # Create each product, all the while tracking any newly created containers in the container map
        Enum.reduce_while(products, {:ok, container_map}, fn {_, product}, {:ok, container_map} ->
          case create_product(project, root_revision, product, container_map, page_map, as_author) do
            {:ok, container_map} -> {:cont, {:ok, container_map}}
            {:error, e} -> {:halt, {:error, e}}
          end
        end)
    end
  end

  # Create a single product. Recursively process the product JSON, reuising containers that already
  # exist, creating new ones when new ones are encountered.
  defp create_product(project, root_revision, product, container_map, page_map, as_author) do
    hierarchy_definition = Map.put(%{}, root_revision.resource_id, [])

    original_container_count = Map.keys(container_map) |> Enum.count()

    # Recursive processing to track new containers and build the hierarchy definition
    {container_map, hierarchy_definition} =
      Map.get(product, "children")
      |> Enum.filter(fn c -> c["type"] == "item" || c["type"] == "container" end)
      |> Enum.reduce({container_map, hierarchy_definition}, fn item,
                                                               {container_map,
                                                                hierarchy_definition} ->
        process_product_item(
          root_revision.resource_id,
          hierarchy_definition,
          project,
          item,
          container_map,
          page_map,
          as_author
        )
      end)

    # If any new containers were created, we have to publish again so that the product can pin
    # a published version of this new container as a section resource
    if Map.keys(container_map) |> Enum.count() != original_container_count do
      Oli.Publishing.publish_project(project, "New containers for product", as_author.id)
    end

    labels =
      Map.get(product, "children")
      |> Enum.filter(fn c -> c["type"] == "labels" end)
      |> Enum.reduce(%{}, fn item, acc ->
        Map.merge(acc, %{
          unit: Map.get(item, "unit"),
          module: Map.get(item, "module"),
          section: Map.get(item, "section")
        })
      end)

    custom_labels =
      case Map.equal?(labels, %{}) do
        true ->
          if project.customizations == nil, do: nil, else: Map.from_struct(project.customizations)

        _ ->
          labels
      end

    new_product_attrs = %{
      "welcome_title" => Map.get(product, "welcomeTitle"),
      "encouraging_subtitle" => Map.get(product, "encouragingSubtitle"),
      "requires_payment" => Map.get(product, "requiresPayment"),
      "payment_options" => Map.get(product, "paymentOptions"),
      "pay_by_institution" => Map.get(product, "payByInstitution"),
      "grace_period_days" => Map.get(product, "gracePeriodDays"),
      "amount" => Map.get(product, "amount"),
      "certificate_enabled" => Map.get(product, "certificateEnabled", false)
    }

    {certificate_params, new_product_attrs} =
      case Map.get(product, "certificate") do
        nil ->
          {nil, new_product_attrs}

        cert ->
          assessments =
            Map.get(cert, "custom_assessments", [])
            |> Enum.map(fn v ->
              Map.get(page_map, Integer.to_string(v)).resource_id
            end)

          cert_params = Map.put(cert, "custom_assessments", assessments)
          product_attrs = Map.put(new_product_attrs, "certificate_enabled", true)
          {cert_params, product_attrs}
      end

    # Create the blueprint (aka 'product'), with the hierarchy definition that was just built
    # to mirror the product JSON.
    case Oli.Delivery.Sections.Blueprint.create_blueprint(
           project.slug,
           product["title"],
           custom_labels,
           hierarchy_definition,
           new_product_attrs
         ) do
      {:ok, blueprint} ->
        maybe_add_certificate(certificate_params, blueprint, container_map)

      e ->
        e
    end
  end

  defp maybe_add_certificate(nil, _blueprint, container_map), do: {:ok, container_map}

  defp maybe_add_certificate(certificate_params, blueprint, container_map) do
    certificate_params = Map.put(certificate_params, "section_id", blueprint.id)

    case Oli.Delivery.Certificates.create(certificate_params) do
      {:ok, _certificate} -> {:ok, container_map}
      e -> e
    end
  end

  defp process_product_item(
         parent_resource_id,
         hierarchy_definition,
         project,
         item,
         container_map,
         page_map,
         as_author
       ) do
    case Map.get(item, "type") do
      "item" ->
        # simply add the item to the parent container in the hierarchy definition. Pages are guaranteed
        # to already exist since all of them are generated during digest creation for all orgs
        id = Map.get(page_map, Map.get(item, "idref")).resource_id

        hierarchy_definition =
          Map.put(
            hierarchy_definition,
            parent_resource_id,
            Map.get(hierarchy_definition, parent_resource_id) ++ [id]
          )

        {container_map, hierarchy_definition}

      "container" ->
        {revision, container_map} =
          case Map.get(container_map, Map.get(item, "id", UUID.uuid4())) do
            # This container is new, we have never enountered it within another org
            nil ->
              attrs = %{
                tags: [],
                title: Map.get(item, "title"),
                intro_content: Map.get(item, "introContent", %{}),
                intro_video: Map.get(item, "introVideo"),
                poster_image: Map.get(item, "posterImage"),
                children: [],
                author_id: as_author.id,
                content: %{"model" => []},
                resource_type_id: Oli.Resources.ResourceType.id_for_container()
              }

              {:ok, %{revision: revision}} =
                Oli.Authoring.Course.create_and_attach_resource(project, attrs)

              {:ok, _} = ChangeTracker.track_revision(project.slug, revision)

              {revision, Map.put(container_map, Map.get(item, "id", UUID.uuid4()), revision)}

            revision ->
              {revision, container_map}
          end

        # Insert this container in the hierarchy with an initially empty collection of children,
        # and also add it to the parent container
        hierarchy_definition =
          Map.put(hierarchy_definition, revision.resource_id, [])
          |> Map.put(
            parent_resource_id,
            Map.get(hierarchy_definition, parent_resource_id) ++ [revision.resource_id]
          )

        # process every child element of this container
        Map.get(item, "children", [])
        |> Enum.reduce({container_map, hierarchy_definition}, fn item,
                                                                 {container_map,
                                                                  hierarchy_definition} ->
          process_product_item(
            revision.resource_id,
            hierarchy_definition,
            project,
            item,
            container_map,
            page_map,
            as_author
          )
        end)
    end
  end

  defp get_registration_map() do
    Oli.Activities.list_activity_registrations()
    |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.slug, e.id) end)
  end

  # Process the _project file to create the project structure
  defp create_project(project_details, as_author, hierarchy) do
    case Map.get(project_details, "title") do
      nil ->
        {:error, :missing_project_title}

      "" ->
        {:error, :empty_project_title}

      title ->
        labels =
          Map.get(hierarchy, "children")
          |> Enum.filter(fn c -> c["type"] == "labels" end)
          |> Enum.reduce(%{}, fn item, acc ->
            Map.merge(acc, %{
              unit: Map.get(item, "unit"),
              module: Map.get(item, "module"),
              section: Map.get(item, "section")
            })
          end)

        custom_labels =
          case Map.equal?(labels, %{}) do
            true -> nil
            _ -> labels
          end

        Oli.Authoring.Course.create_project(title, as_author, %{
          description: Map.get(project_details, "description"),
          legacy_svn_root: Map.get(project_details, "svnRoot"),
          customizations: custom_labels,
          attributes: Map.get(project_details, "attributes"),
          welcome_title: Map.get(project_details, "welcomeTitle"),
          encouraging_subtitle: Map.get(project_details, "encouragingSubtitle")
        })
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

  defp create_bibentries(project, resource_map, as_author) do
    bibentries =
      Map.keys(resource_map)
      |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
      |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Bibentry" end)

    Repo.transaction(fn ->
      case Enum.reduce_while(bibentries, %{}, fn {id, bibentry}, map ->
             case create_bibentry(project, bibentry, as_author) do
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
  defp create_pages(
         project_details,
         project,
         resource_map,
         activity_map,
         objective_map,
         tag_map,
         bib_map,
         as_author
       ) do
    {changes, pages} =
      Map.keys(resource_map)
      |> Enum.map(fn k -> {k, Map.get(resource_map, k)} end)
      |> Enum.filter(fn {_, content} -> Map.get(content, "type") == "Page" end)
      |> scrub_resources()

    required_student_survey_id = Map.get(project_details, "required_student_survey")

    Repo.transaction(fn ->
      case Enum.reduce_while(pages, %{}, fn {id, page}, map ->
             case create_page(
                    project,
                    page,
                    activity_map,
                    objective_map,
                    tag_map,
                    bib_map,
                    as_author
                  ) do
               {:ok, revision} ->
                 if id == required_student_survey_id,
                   do:
                     Course.update_project(project, %{
                       required_survey_resource_id: revision.resource_id
                     })

                 {:cont, Map.put(map, id, revision)}

               {:error, e} ->
                 {:halt, {:error, e}}
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
    PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
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

  defp rewire_report_activity_references(content, activity_map) do
    PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
      case e do
        %{"type" => "report", "activityId" => original} = ref ->
          case retrieve(activity_map, original) do
            nil ->
              {ref, {:error, [original | invalid_refs]}}

            retrieved ->
              {Map.put(ref, "activityId", retrieved.resource_id), {status, invalid_refs}}
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
    PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
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

  defp rewire_bib_refs(%{"type" => "content", "children" => _children} = content, bib_map) do
    PageContent.bibliography_rewire(content, {:ok, []}, fn i, {status, bibrefs}, _tr_context ->
      case i do
        %{"type" => "cite", "bibref" => bibref} = ref ->
          bib_id = Map.get(Map.get(bib_map, bibref, %{resource_id: bibref}), :resource_id)
          {Map.put(ref, "bibref", bib_id), {status, bibrefs ++ [bib_id]}}

        other ->
          {other, {status, bibrefs}}
      end
    end)
  end

  defp rewire_citation_references(content, bib_map) do
    brefs =
      Enum.reduce(Map.get(content, "bibrefs", []), [], fn k, acc ->
        if Map.has_key?(bib_map, k) do
          acc ++ [Map.get(Map.get(bib_map, k, %{id: k}), :resource_id)]
        else
          acc
        end
      end)

    bcontent = Map.put(content, "bibrefs", brefs)

    PageContent.map_reduce(bcontent, {:ok, []}, fn e, {status, bibrefs}, _tr_context ->
      case e do
        %{"type" => "content"} = ref ->
          rewire_bib_refs(ref, bib_map)

        other ->
          {other, {status, bibrefs}}
      end
    end)
    |> case do
      {mapped, {:ok, _bibrefs}} ->
        {:ok, mapped}

      {_mapped, {:error, _bibrefs}} ->
        {:error, {:rewire_citation_references, "error"}}
    end
  end

  # Create one page
  defp create_page(project, page, activity_map, objective_map, tag_map, bib_map, as_author) do
    with {:ok, %{"content" => content} = page} <- maybe_migrate_resource_content(page, :page),
         :ok <- validate_json(content, SchemaResolver.resolve("page-content.schema.json")),
         {:ok, content} <- rewire_activity_references(content, activity_map),
         {:ok, content} <- rewire_report_activity_references(content, activity_map),
         {:ok, content} <- rewire_bank_selections(content, tag_map),
         {:ok, content} <- rewire_citation_references(content, bib_map) do
      graded = Map.get(page, "isGraded", false)

      legacy_id = Map.get(page, "legacyId", nil)
      legacy_path = Map.get(page, "legacyPath", nil)

      %{
        legacy: %{id: legacy_id, path: legacy_path},
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
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        scoring_strategy_id:
          Map.get(page, "scoringStrategyId", Oli.Resources.ScoringStrategy.get_id_by_type("best")),
        graded: graded,
        relates_to:
          Map.get(page, "relatesTo", []) |> Enum.map(fn id -> String.to_integer(id) end),
        max_attempts: Map.get(page, "maxAttempts", if(graded, do: 5, else: 0)),
        explanation_strategy:
          Map.get(page, "explanationStrategy", graded)
          |> get_explanation_strategy(),
        intro_content: Map.get(page, "introContent", %{}),
        intro_video: Map.get(page, "introVideo"),
        poster_image: Map.get(page, "posterImage"),
        recommended_attempts: Map.get(page, "recommendedAttempts", 5),
        duration_minutes: Map.get(page, "durationMinutes"),
        full_progress_pct: Map.get(page, "fullProgressPct", 100),
        retake_mode: Map.get(page, "retakeMode", "normal") |> String.to_atom(),
        assessment_mode: Map.get(page, "assessmentMode", "traditional") |> String.to_atom()
      }
      |> create_resource(project)
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
    with {:ok, %{"content" => content} = activity} <-
           maybe_migrate_resource_content(activity, :activity),
         :ok <- validate_json(activity, SchemaResolver.resolve("activity.schema.json")) do
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

      legacy_id = Map.get(activity, "legacyId", nil)
      legacy_path = Map.get(activity, "legacyPath", nil)

      %{
        legacy: %{id: legacy_id, path: legacy_path},
        scope: scope,
        tags: transform_tags(activity, tag_map),
        title: title,
        content: content,
        author_id: as_author.id,
        objectives: process_activity_objectives(activity, objective_map),
        resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
        activity_type_id: Map.get(registration_by_subtype, Map.get(activity, "subType")),
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average")
      }
      |> create_resource(project)
    end
  end

  defp maybe_migrate_resource_content(resource, resource_type) do
    {:ok,
     Map.put(
       resource,
       "content",
       ContentMigrator.migrate(Map.get(resource, "content"), resource_type, to: :latest)
     )}
  end

  defp validate_json(json, schema) do
    case ExJsonSchema.Validator.validate(schema, json) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error, {:invalid_json, schema, errors, json}}
    end
  end

  defp create_tag(project, tag, as_author) do
    %{
      tags: [],
      title: Map.get(tag, "title", "empty tag"),
      content: %{},
      author_id: as_author.id,
      objectives: %{},
      resource_type_id: Oli.Resources.ResourceType.id_for_tag()
    }
    |> create_resource(project)
  end

  defp create_bibentry(project, bibentry, as_author) do
    %{
      tags: [],
      title: Map.get(bibentry, "title", "empty bibentry"),
      content: Map.get(bibentry, "content", %{}),
      author_id: as_author.id,
      objectives: %{},
      resource_type_id: Oli.Resources.ResourceType.id_for_bibentry()
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

    parameters = Map.get(objective, "parameters", nil)
    legacy_id = Map.get(objective, "legacyId", nil)
    legacy_path = Map.get(objective, "legacyPath", nil)

    %{
      legacy: %{id: legacy_id, path: legacy_path},
      tags: transform_tags(objective, tag_map),
      title: title,
      content: %{},
      author_id: as_author.id,
      objectives: %{},
      parameters: parameters,
      children:
        Map.get(objective, "objectives", [])
        |> Enum.map(fn id -> Map.get(objective_map, id).resource_id end),
      resource_type_id: Oli.Resources.ResourceType.id_for_objective()
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
    # Process top-level items and containers, add recursively add container
    {container_map, children} =
      Map.get(hierarchy_details, "children")
      |> Enum.filter(fn c -> c["type"] == "item" || c["type"] == "container" end)
      |> Enum.reduce({%{}, []}, fn c, {container_map, children} ->
        case Map.get(c, "type") do
          "item" ->
            {container_map, children ++ [Map.get(page_map, Map.get(c, "idref")).resource_id]}

          "container" ->
            {container_map, id} =
              create_container(project, page_map, as_author, tag_map, c, container_map)

            {container_map, children ++ [id]}
        end
      end)

    # wire those newly created top-level containers into the root resource
    ChangeTracker.track_revision(project.slug, root_revision, %{children: children})

    {:ok, container_map}
  end

  # This is the recursive container creation routine.  It processes a hierarchy by
  # descending through the tree and processing the leaves first, and then back upwards.
  defp create_container(project, page_map, as_author, tag_map, container, container_map) do
    # recursively visit item container in the hierarchy, and via bottom
    # up approach create resource and revisions for each container, while
    # substituting page references for resource ids and container references
    # for container resource ids

    {container_map, children_ids} =
      Map.get(container, "children")
      |> Enum.reduce({container_map, []}, fn c, {container_map, children} ->
        case Map.get(c, "type") do
          "item" ->
            p = Map.get(page_map, Map.get(c, "idref"))
            {container_map, children ++ [p.resource_id]}

          "container" ->
            {container_map, id} =
              create_container(project, page_map, as_author, tag_map, c, container_map)

            {container_map, children ++ [id]}
        end
      end)

    attrs = %{
      tags: transform_tags(container, tag_map),
      title: Map.get(container, "title"),
      intro_content: Map.get(container, "introContent", %{}),
      intro_video: Map.get(container, "introVideo"),
      poster_image: Map.get(container, "posterImage"),
      children: children_ids,
      author_id: as_author.id,
      content: %{"model" => []},
      resource_type_id: Oli.Resources.ResourceType.id_for_container()
    }

    {:ok, %{revision: revision}} = Oli.Authoring.Course.create_and_attach_resource(project, attrs)
    {:ok, _} = ChangeTracker.track_revision(project.slug, revision)

    container_map = Map.put(container_map, Map.get(container, "id", UUID.uuid4()), revision)

    {container_map, revision.resource_id}
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

  defp process_activity_objectives(activity, objective_map) do
    case Map.get(activity, "objectives", []) do
      map when is_map(map) ->
        Map.keys(map)
        |> Enum.reduce(%{}, fn k, m ->
          mapped =
            Map.get(activity, "objectives")[k]
            |> Enum.map(fn id ->
              case Map.get(objective_map, id) do
                nil ->
                  IO.inspect("Missing objective #{id}")
                  nil

                o ->
                  o.resource_id
              end
            end)
            |> Enum.filter(fn id -> !is_nil(id) end)

          Map.put(m, k, mapped)
        end)

      list when is_list(list) ->
        activity["content"]["authoring"]["parts"]
        |> Enum.map(fn %{"id" => id} -> id end)
        |> Enum.reduce(%{}, fn e, m ->
          objectives =
            Enum.map(list, fn id ->
              case Map.get(objective_map, id) do
                nil ->
                  IO.inspect("Missing objective #{id}")
                  nil

                o ->
                  o.resource_id
              end
            end)
            |> Enum.filter(fn id -> !is_nil(id) end)

          Map.put(m, e, objectives)
        end)
    end
  end

  defp get_explanation_strategy(%{"type" => type, "set_num_attempts" => set_num_attempts}) do
    %Oli.Resources.ExplanationStrategy{
      type: String.to_atom(type),
      set_num_attempts: set_num_attempts
    }
  end

  defp get_explanation_strategy(true) do
    %Oli.Resources.ExplanationStrategy{type: :after_max_resource_attempts_exhausted}
  end

  defp get_explanation_strategy(false) do
    %Oli.Resources.ExplanationStrategy{type: :after_set_num_attempts, set_num_attempts: 2}
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
