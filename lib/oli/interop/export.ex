defmodule Oli.Interop.Export do
  require Logger

  alias Oli.Publishing
  alias Oli.Resources.ResourceType
  alias Oli.Activities
  alias Oli.Authoring.MediaLibrary
  alias Oli.Authoring.MediaLibrary.ItemOptions
  alias Oli.Utils
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Delivery.Sections.BlueprintBrowseOptions
  alias Oli.Repo

  @page_resource_type_id ResourceType.id_for_page()

  @doc """
  Generates a course digest for an existing course project.
  """
  def export(project) do
    publication = Publishing.project_working_publication(project.slug)
    resources = fetch_all_resources(publication)
    page_slug_to_resource_id = page_slug_to_resource_id(resources)

    ([
       create_project_file(project),
       create_media_manifest_file(project),
       create_hierarchy_file(resources, publication, project)
     ] ++
       tags(resources) ++
       objectives(resources) ++
       activities(resources, project, page_slug_to_resource_id) ++
       bib_entries(resources) ++
       alternatives(resources) ++
       pages(resources, project, page_slug_to_resource_id) ++
       products(project))
    |> Utils.zip("export.zip")
  end

  defp tags(resources) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.id_for_tag()
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
      r.resource_type_id == ResourceType.id_for_objective()
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
  defp activities(resources, project, page_slug_to_resource_id) do
    registrations =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.id, r) end)

    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.id_for_activity()
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
        content: rewire_activity_content(r.content, project, page_slug_to_resource_id),
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

  defp rewire_elements(content, project, page_slug_to_resource_id) do
    Oli.Resources.PageContent.visit_children(content, {:ok, []}, fn c,
                                                                    {status, []},
                                                                    _tr_context ->
      case {Map.get(c, "type"), Map.get(c, "tag")} do
        {"cite", _} ->
          {Map.put(c, "bibref", "#{Map.get(c, "bibref")}"), {status, []}}

        {"page_link", _} ->
          {Map.put(c, "idref", "#{Map.get(c, "idref")}"), {status, []}}

        {"a", _} ->
          {rewire_internal_anchor(c, project, page_slug_to_resource_id), {status, []}}

        {_, "a"} ->
          {rewire_internal_anchor(c, project, page_slug_to_resource_id), {status, []}}

        _ ->
          {c, {status, []}}
      end
    end)
  end

  defp rewire_internal_anchor(node, _project, page_slug_to_resource_id) do
    cond do
      not is_nil(Map.get(node, "idref")) ->
        idref = "#{Map.get(node, "idref")}"

        node
        |> Map.put("idref", idref)
        |> Map.put("resource_id", idref)
        |> maybe_mark_internal_link()

      true ->
        case page_slug_from_internal_href(Map.get(node, "href")) do
          {:ok, slug} ->
            case resolve_page_resource_id(slug, page_slug_to_resource_id) do
              {:ok, resource_id} ->
                idref = "#{resource_id}"

                node
                |> Map.put("idref", idref)
                |> Map.put("resource_id", idref)
                |> maybe_mark_internal_link()

              nil ->
                Logger.warning(
                  "Skipping adaptive link export rewiring, unknown slug #{inspect(slug)}"
                )

                node
            end

          :ignore ->
            node
        end
    end
  end

  defp maybe_mark_internal_link(%{"tag" => "a"} = node), do: Map.put_new(node, "linkType", "page")
  defp maybe_mark_internal_link(node), do: node

  defp page_slug_from_internal_href("/course/link/" <> rest) do
    case String.split(rest, ["?", "#"], parts: 2) do
      [slug | _] when slug != "" -> {:ok, slug}
      _ -> :ignore
    end
  end

  defp page_slug_from_internal_href(_), do: :ignore

  defp resolve_page_resource_id(revision_slug, page_slug_to_resource_id) do
    case Map.get(page_slug_to_resource_id, revision_slug) do
      resource_id when is_integer(resource_id) ->
        {:ok, resource_id}

      _ ->
        nil
    end
  end

  # For activity payloads, perform one defensive full-tree traversal so links in both
  # standard and legacy/non-standard locations are normalized in a single pass.
  defp rewire_activity_content(content, project, page_slug_to_resource_id) do
    if maybe_export_link_subtree?(content) do
      {rewired, _changed?} =
        deep_rewire_activity_nodes_tracked(content, project, page_slug_to_resource_id)

      rewired
    else
      content
    end
  end

  defp deep_rewire_activity_nodes_tracked(value, _project, _page_slug_to_resource_id)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: {value, false}

  defp deep_rewire_activity_nodes_tracked(items, project, page_slug_to_resource_id)
       when is_list(items) do
    if not maybe_export_link_subtree?(items) do
      {items, false}
    else
      {rewritten_items, changed?} =
        Enum.reduce(items, {[], false}, fn item, {acc, changed?} ->
          if maybe_export_link_subtree?(item) do
            {rewritten_item, item_changed?} =
              deep_rewire_activity_nodes_tracked(item, project, page_slug_to_resource_id)

            {[rewritten_item | acc], changed? || item_changed?}
          else
            {[item | acc], changed?}
          end
        end)

      if changed? do
        {Enum.reverse(rewritten_items), true}
      else
        {items, false}
      end
    end
  end

  defp deep_rewire_activity_nodes_tracked(map, project, page_slug_to_resource_id)
       when is_map(map) do
    if not maybe_export_link_subtree?(map) do
      {map, false}
    else
      {rewritten_children, children_changed?} =
        Enum.reduce(map, {nil, false}, fn {key, value}, {acc, changed?} ->
          if maybe_export_link_subtree?(value) do
            {rewritten_value, value_changed?} =
              deep_rewire_activity_nodes_tracked(value, project, page_slug_to_resource_id)

            cond do
              value_changed? ->
                target = if is_nil(acc), do: map, else: acc
                {Map.put(target, key, rewritten_value), true}

              changed? ->
                {acc, true}

              true ->
                {acc, false}
            end
          else
            {acc, changed?}
          end
        end)

      base = if children_changed?, do: rewritten_children, else: map

      {rewritten_node, node_changed?} =
        rewrite_activity_node_tracked(base, project, page_slug_to_resource_id)

      {rewritten_node, children_changed? || node_changed?}
    end
  end

  defp deep_rewire_activity_nodes_tracked(value, _project, _page_slug_to_resource_id),
    do: {value, false}

  defp rewrite_activity_node_tracked(
         %{"type" => "cite"} = node,
         _project,
         _page_slug_to_resource_id
       ) do
    rewritten = Map.put(node, "bibref", "#{Map.get(node, "bibref")}")
    {rewritten, rewritten != node}
  end

  defp rewrite_activity_node_tracked(
         %{"type" => "page_link"} = node,
         _project,
         _page_slug_to_resource_id
       ) do
    rewritten = Map.put(node, "idref", "#{Map.get(node, "idref")}")
    {rewritten, rewritten != node}
  end

  defp rewrite_activity_node_tracked(%{"type" => "a"} = node, project, page_slug_to_resource_id) do
    rewritten = rewire_internal_anchor(node, project, page_slug_to_resource_id)
    {rewritten, rewritten != node}
  end

  defp rewrite_activity_node_tracked(%{"tag" => "a"} = node, project, page_slug_to_resource_id) do
    rewritten = rewire_internal_anchor(node, project, page_slug_to_resource_id)
    {rewritten, rewritten != node}
  end

  defp rewrite_activity_node_tracked(node, _project, _page_slug_to_resource_id), do: {node, false}

  @activity_link_container_keys ~w[
    children
    content
    model
    stem
    choices
    authoring
    parts
    responses
    feedback
    hints
    custom
    nodes
    partsLayout
    caption
    pronunciation
    translations
  ]

  defp maybe_export_link_subtree?(%{} = node) do
    direct_link_node? =
      Map.has_key?(node, "idref") or
        Map.get(node, "type") in ["a", "page_link", "cite"] or
        Map.get(node, "tag") == "a" or
        page_slug_from_internal_href(Map.get(node, "href")) != :ignore

    has_known_link_container? =
      Enum.any?(node, fn {key, _value} -> key in @activity_link_container_keys end)

    has_nested_structures? =
      Enum.any?(node, fn {_key, value} -> is_map(value) or is_list(value) end)

    direct_link_node? or has_known_link_container? or has_nested_structures?
  end

  defp maybe_export_link_subtree?(items) when is_list(items) do
    Enum.any?(items, fn item -> is_map(item) or is_list(item) end)
  end

  defp maybe_export_link_subtree?(_), do: false

  def rewire(content, project, page_slug_to_resource_id) do
    {content, _} =
      Oli.Resources.PageContent.map_reduce(content, {:ok, []}, fn e, {status, []}, _tr_context ->
        case e do
          %{"type" => "content"} = ref ->
            rewire_elements(ref, project, page_slug_to_resource_id)

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
  defp pages(resources, project, page_slug_to_resource_id) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.id_for_page()
    end)
    |> Enum.map(fn r ->
      %{
        type: "Page",
        id: Integer.to_string(r.resource_id, 10),
        originalFile: "",
        title: r.title,
        tags: transform_tags(r),
        unresolvedReferences: [],
        content: rewire(r.content, project, page_slug_to_resource_id),
        objectives: Map.get(r.objectives, "attached", []) |> Enum.map(fn id -> "#{id}" end),
        isGraded: r.graded,
        purpose: r.purpose,
        relatesTo: r.relates_to |> Enum.map(fn id -> "#{id}" end),
        collabSpace: r.collab_space_config,
        introContent: r.intro_content,
        introVideo: r.intro_video,
        posterImage: r.poster_image,
        scoringStrategyId: r.scoring_strategy_id,
        explanationStrategy: r.explanation_strategy,
        maxAttempts: r.max_attempts,
        recommendedAttempts: r.recommended_attempts,
        durationMinutes: r.duration_minutes,
        fullProgressPct: r.full_progress_pct,
        retakeMode: r.retake_mode,
        assessmentMode: r.assessment_mode
      }
      |> entry("#{r.resource_id}.json")
    end)
  end

  defp page_slug_to_resource_id(resources) do
    resources
    |> Enum.reduce(%{}, fn revision, acc ->
      if revision.resource_type_id == @page_resource_type_id and is_binary(revision.slug) do
        Map.put(acc, revision.slug, revision.resource_id)
      else
        acc
      end
    end)
  end

  defp bib_entries(resources) do
    Enum.filter(resources, fn r ->
      r.resource_type_id == ResourceType.id_for_bibentry()
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
      r.resource_type_id == ResourceType.id_for_alternatives()
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

  def products(project) do
    # get all products in this project
    products =
      Blueprint.list(%BlueprintBrowseOptions{
        project_id: project.id,
        include_archived: false
      })
      |> Repo.preload([:certificate, section_project_publications: [:publication]])
      |> Enum.filter(&(length(&1.section_project_publications) == 1))

    product_ids = products |> Enum.map(& &1.id)

    # build for each product a list of all published resources
    published_resources_by_sections =
      Publishing.get_published_resources_for_products(product_ids)
      |> Enum.group_by(fn {product_id, _} -> product_id end)

    Enum.map(products, fn product ->
      resources = Map.get(published_resources_by_sections, product.id)
      create_product_file(resources, product)
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
    required_survey_resource_id =
      if project.required_survey_resource_id == nil,
        do: nil,
        else: Integer.to_string(project.required_survey_resource_id)

    %{
      title: project.title,
      description: project.description,
      welcomeTitle: project.welcome_title,
      encouragingSubtitle: project.encouraging_subtitle,
      type: "Manifest",
      required_student_survey: required_survey_resource_id,
      attributes: Map.get(project, :attributes)
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
  defp create_hierarchy_file(resources, publication, project) do
    revisions_by_id = Enum.reduce(resources, %{}, fn r, m -> Map.put(m, r.resource_id, r) end)
    root = Map.get(revisions_by_id, publication.root_resource_id)
    customizations = Map.get(project, :customizations)

    %{
      type: "Hierarchy",
      id: "",
      originalFile: "",
      title: "",
      tags: transform_tags(root),
      children:
        Enum.map(root.children, fn id -> full_hierarchy(revisions_by_id, id) end) ++
          unless(is_nil(customizations),
            do: [
              Map.merge(
                %{
                  type: "labels"
                },
                Map.from_struct(customizations)
              )
            ],
            else: []
          )
    }
    |> entry("_hierarchy.json")
  end

  # create the singular hierarchy file for products
  defp create_product_file(resources, product) do
    publication = Enum.at(product.section_project_publications, 0).publication

    resources_by_section_resources =
      Enum.map(resources, fn {_product_id,
                              %{revision: _revision, section_resource: section_resource}} ->
        {section_resource.id, section_resource.resource_id}
      end)
      |> Enum.into(%{})

    revisions_by_resource_id =
      Enum.reduce(resources, %{}, fn {_product_id,
                                      %{revision: revision, section_resource: section_resource}},
                                     m ->
        Map.put(
          m,
          section_resource.resource_id,
          Map.put(
            revision,
            :children,
            (Map.get(section_resource, :children) || [])
            |> Enum.map(fn id -> Map.get(resources_by_section_resources, id) end)
          )
        )
      end)

    root = Map.get(revisions_by_resource_id, publication.root_resource_id)

    Enum.map(root.children, fn id -> full_hierarchy(revisions_by_resource_id, id) end)

    certificate =
      case product.certificate do
        nil ->
          nil

        cert ->
          cert
          |> Map.from_struct()
          |> Map.drop([
            :__meta__,
            :__struct__,
            :id,
            :inserted_at,
            :updated_at,
            :section,
            :granted_certificate
          ])
      end

    %{
      type: "Product",
      id: "_product-#{product.id}",
      originalFile: "",
      title: product.title,
      description: product.description,
      welcomeTitle: product.welcome_title,
      encouragingSubtitle: product.encouraging_subtitle,
      requiresPayment: product.requires_payment,
      paymentOptions: product.payment_options,
      payByInstitution: product.pay_by_institution,
      gracePeriodDays: product.grace_period_days,
      amount: product.amount,
      certificateEnabled: product.certificate_enabled,
      certificate: certificate,
      children: Enum.map(root.children, fn id -> full_hierarchy(revisions_by_resource_id, id) end)
    }
    |> entry("_product-#{product.id}.json")
  end

  # helper to create a zip entry tuple
  defp entry(contents, name) do
    {String.to_charlist(name), Utils.pretty(contents)}
  end

  # recursive impl to build out the nested, digest specific representation of the course hierarchy
  defp full_hierarchy(revisions_by_id, resource_id) do
    revision = Map.get(revisions_by_id, resource_id)

    if revision do
      case ResourceType.get_type_by_id(revision.resource_type_id) do
        "container" ->
          %{
            type: "container",
            id: "#{resource_id}",
            title: revision.title,
            introContent: revision.intro_content,
            introVideo: revision.intro_video,
            posterImage: revision.poster_image,
            tags: transform_tags(revision),
            children:
              Enum.map(revision.children, fn id -> full_hierarchy(revisions_by_id, id) end)
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

  defp transform_tags(revision) do
    Enum.map(revision.tags, fn id -> Integer.to_string(id, 10) end)
  end
end
