defmodule Oli.Delivery.Sections.Blueprint do
  import Ecto.Query, warn: false

  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Course.ProjectVisibility
  alias Oli.Publishing.Publications.Publication
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.BlueprintBrowseOptions
  alias Oli.Groups.CommunityVisibility
  alias Oli.Institutions.Institution
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  @doc """
  From a slug, retrieve a valid section blueprint.  A section is a
  valid blueprint when that section is of type :blueprint and the status
  is active.

  Returns nil when there is no matching valid blueprint for the slug.
  """
  def get_active_blueprint(slug) do
    case Repo.get_by(Section, slug: slug) do
      nil -> nil
      %Section{type: :blueprint, status: :active} = section -> section
      _ -> nil
    end
  end

  @doc """
  From a slug, retrieve a valid section blueprint.  A section is a
  valid blueprint when that section is of type :blueprint and the status
  is active.

  Returns nil when there is no matching valid blueprint for the slug.
  """
  def get_blueprint(slug) do
    case Repo.get_by(Section, slug: slug) do
      nil -> nil
      %Section{type: :blueprint} = section -> section
      _ -> nil
    end
  end

  def get_blueprint_by_base_project(project) do
    from(s in Section,
      where: s.base_project_id == ^project.id and s.type == :blueprint
    )
    |> Repo.all()
  end

  def is_author_of_blueprint?(section_slug, author_id) do
    query =
      from(
        s in Oli.Delivery.Sections.Section,
        join: p in Project,
        on: s.base_project_id == p.id,
        join: a in Oli.Authoring.Authors.AuthorProject,
        on: a.project_id == p.id,
        where: s.slug == ^section_slug and s.type == :blueprint and a.author_id == ^author_id,
        select: s
      )

    case Repo.aggregate(query, :count, :id) do
      0 -> false
      _ -> true
    end
  end

  @doc """
  For a given author that belongs to a specific institution, return all active
  prodcuts that this author has visibility to.
  """
  def available_products(%Author{} = author, %Institution{} = institution) do
    query =
      from section in Section,
        join: proj in Project,
        on: proj.id == section.base_project_id,
        join: pub in Publication,
        on: pub.project_id == proj.id,
        left_join: a in assoc(proj, :authors),
        left_join: v in ProjectVisibility,
        on: proj.id == v.project_id,
        where:
          section.type == :blueprint and
            section.status == :active and
            not is_nil(pub.published) and proj.status == :active and
            (a.id == ^author.id or proj.visibility == :global or
               (proj.visibility == :selected and
                  (v.author_id == ^author.id or v.institution_id == ^institution.id))),
        distinct: true,
        select: section

    Repo.all(query)
  end

  def available_products(nil, _institution), do: available_products()

  def available_products() do
    query =
      from section in Section,
        join: proj in Project,
        on: proj.id == section.base_project_id,
        join: pub in Publication,
        on: pub.project_id == proj.id,
        left_join: a in assoc(proj, :authors),
        left_join: v in ProjectVisibility,
        on: proj.id == v.project_id,
        where:
          section.type == :blueprint and
            section.status == :active and
            not is_nil(pub.published) and proj.status == :active and proj.visibility == :global,
        distinct: true,
        select: section

    Repo.all(query)
  end

  @doc """
  From a list of visible products and visible publciations of projects, filter out
  the project publications that have at least one paid product.
  """
  def filter_for_free_projects(all_products, publications) do
    has_paid_product =
      Enum.filter(all_products, fn p -> p.status == :active and p.requires_payment end)
      |> Enum.map(fn p -> p.base_project_id end)
      |> MapSet.new()

    Enum.filter(publications, fn pub -> !MapSet.member?(has_paid_product, pub.project_id) end)
  end

  @doc """
  Given a base project slug and a title, create a course section blueprint.

  This creates the "section" record and "section resource" records to mirror
  the current published structure of the course project hierarchy.
  """
  def create_blueprint(
        base_project_slug,
        title,
        custom_labels,
        hierarchy_definition \\ nil,
        attrs \\ %{}
      ) do
    Repo.transaction(fn _ ->
      case Oli.Authoring.Course.get_project_by_slug(base_project_slug) do
        nil ->
          {:error, {:invalid_project}}

        project ->
          new_blueprint = %{
            "type" => :blueprint,
            "status" => :active,
            "base_project_id" => project.id,
            "open_and_free" => false,
            "context_id" => UUID.uuid4(),
            "start_date" => nil,
            "end_date" => nil,
            "title" => title,
            "requires_payment" => attrs["requires_payment"] || false,
            "payment_options" => attrs["payment_options"] || "direct_and_deferred",
            "pay_by_institution" => attrs["pay_by_institution"] || false,
            "registration_open" => attrs["registration_open"] || false,
            "grace_period_days" => attrs["grace_period_days"] || 1,
            "amount" =>
              Money.new(attrs["amount"]["currency"] || :USD, attrs["amount"]["amount"] || "25.00"),
            "publisher_id" => project.publisher_id,
            "customizations" => custom_labels,
            "welcome_title" => attrs["welcome_title"] || project.welcome_title,
            "encouraging_subtitle" =>
              attrs["encouraging_subtitle"] || project.encouraging_subtitle
          }

          case Sections.create_section(new_blueprint) do
            {:ok, blueprint} ->
              publication =
                Oli.Publishing.get_latest_published_publication_by_slug(base_project_slug)

              case Sections.create_section_resources(blueprint, publication, hierarchy_definition) do
                {:ok, section} -> PostProcessing.apply(section, :all)
                {:error, e} -> Repo.rollback(e)
              end

            {:error, e} ->
              Repo.rollback(e)
          end
      end
    end)
  end

  @doc """
  Duplicates a blueprint section, creating a new top-level section record
  as well as deep copying all SectionResource and SectionProjectPublication records.

  This method supports duplication of enrollable sections to create a blueprint.

  If this method is called with a `cloned_from_project_publication_ids` parameter, it will update the
  section_project_publications an section_resource records corresponding to that project id.
  This is useful when duplicating a blueprint/product that was part of a project that is being
  cloned. If this parameter is not provided, then the project_id of the section_project_publications
  will remain the same as the original project id.
  """
  def duplicate(%Section{} = section, attrs \\ %{}, cloned_from_project_publication_ids \\ nil) do
    Repo.transaction(fn _ ->
      with {:ok, blueprint} <- dupe_section(section, attrs),
           {:ok, _} <-
             dupe_section_project_publications(
               section,
               blueprint,
               cloned_from_project_publication_ids
             ),
           {:ok, duplicated_root_resource} <-
             dupe_section_resources(section, blueprint, cloned_from_project_publication_ids),
           {:ok, blueprint} <-
             Sections.update_section(blueprint, %{
               root_section_resource_id: duplicated_root_resource.id
             }) do
        Oli.Delivery.Gating.duplicate_gates(section, blueprint)

        blueprint
      else
        {:error, e} -> Repo.rollback(e)
      end
    end)
  end

  defp dupe_section(%Section{} = section, attrs) do
    custom_labels =
      if section.customizations == nil, do: nil, else: Map.from_struct(section.customizations)

    params =
      Map.merge(
        %{
          type: :blueprint,
          status: :active,
          base_project_id: section.base_project_id,
          open_and_free: false,
          context_id: UUID.uuid4(),
          start_date: nil,
          end_date: nil,
          title: section.title <> " Copy",
          invite_token: nil,
          passcode: nil,
          blueprint_id: nil,
          lti_1p3_deployment_id: nil,
          institution_id: nil,
          brand_id: nil,
          delivery_policy_id: nil,
          customizations: custom_labels,
          contains_explorations: section.contains_explorations,
          contains_deliberate_practice: section.contains_deliberate_practice,
          cover_image: section.cover_image,
          skip_email_verification: section.skip_email_verification,
          registration_open: section.registration_open,
          requires_enrollment: section.requires_enrollment,
          certificate: Oli.Repo.preload(section, :certificate).certificate
        },
        attrs
      )

    Map.merge(
      Map.from_struct(section),
      params
    )
    |> Map.delete(:id)
    |> Map.delete(:slug)
    |> Sections.create_section()
  end

  defp dupe_section_resources(
         %Section{id: id, root_section_resource_id: root_id},
         %Section{} = blueprint,
         cloned_from_project_publication_ids
       ) do
    Repo.transaction(fn ->
      query =
        from(
          s in Oli.Delivery.Sections.SectionResource,
          where: s.section_id == ^id,
          select: s
        )

      resources = Repo.all(query)

      # Create the maps for each section resource by duplicating the existing ones
      # and set the section_id to be the id of the blueprint
      resources_to_create =
        Enum.reverse(resources)
        |> Enum.reduce([], fn p, resources_to_create ->
          # same process as sections_project_publications, if this blueprint was duplicated
          # as part of a project cloning, we need to update the project_id of the section_resource
          # if the section_resource belongs to the original project
          project_id =
            case cloned_from_project_publication_ids do
              {cloned_from_project_id, _} ->
                if p.project_id == cloned_from_project_id do
                  blueprint.base_project_id
                else
                  p.project_id
                end

              _ ->
                p.project_id
            end

          resource =
            Map.merge(Sections.SectionResource.to_map(p), %{
              section_id: blueprint.id,
              project_id: project_id
            })
            |> Map.delete(:id)

          [resource | resources_to_create]
        end)

      # Insert all the new (duplicated) section resources in the database (at this point
      # the children of each section resource will be wrongly mapped to its original section resource)
      {_count, results} =
        Sections.bulk_create_section_resource(resources_to_create, returning: true)

      results = Enum.map(results, &Sections.SectionResource.to_map(&1))

      resource_map =
        Enum.zip(resources, results)
        |> Enum.reduce(%{}, fn {original, duplicate}, m ->
          Map.put(m, original.id, duplicate.id)
        end)

      # Change the newly created section resources children so that they point to the correct
      # section resource
      section_resources =
        Enum.reduce(results, [], fn sr, section_resources ->
          sr =
            Map.put(
              sr,
              :children,
              Enum.map(sr.children, fn id -> Map.get(resource_map, id) end)
            )

          [sr | section_resources]
        end)

      # Update all section resources at the same time
      {_cont, rows} = Sections.bulk_update_section_resource(section_resources, returning: true)

      # Return the section resource that corresponds to the original root resource
      Enum.find(rows, &(Map.get(resource_map, root_id) == &1.id))
    end)
  end

  defp dupe_section_project_publications(
         %Section{id: id},
         %Section{} = blueprint,
         cloned_from_project_publication_ids
       ) do
    query =
      from(
        s in Oli.Delivery.Sections.SectionsProjectsPublications,
        where: s.section_id == ^id,
        select: s
      )

    Repo.all(query)
    |> Enum.reduce_while({:ok, []}, fn spp, {:ok, all} ->
      # In the case where a project is cloned with products, these product blueprints are no longer associated with the
      # original project id. So we must use the provided project id in `cloned_from_project_publication_ids` to identify the
      # section_project_publication record associated with the original project id and update it to
      # the new project and publication ids.
      #
      # In the other cases where we are simply duplicating a blueprint, the project_id should remain
      # the same as the original project id, which is the base_project_id of the blueprint
      {project_id, publication_id} =
        case cloned_from_project_publication_ids do
          {cloned_from_project_id, cloned_publication_id} ->
            if spp.project_id == cloned_from_project_id do
              {blueprint.base_project_id, cloned_publication_id}
            else
              {spp.project_id, spp.publication_id}
            end

          _ ->
            {spp.project_id, spp.publication_id}
        end

      attrs = %{
        section_id: blueprint.id,
        project_id: project_id,
        publication_id: publication_id
      }

      case Sections.create_section_project_publication(attrs) do
        {:ok, copy} -> {:cont, {:ok, [copy | all]}}
        {:error, e} -> {:halt, {:error, e}}
      end
    end)
  end

  def list() do
    query =
      from(
        s in Section,
        where: s.type == :blueprint and s.status == :active,
        select: s,
        preload: [:base_project]
      )

    Repo.all(query)
  end

  def list(%BlueprintBrowseOptions{} = options) do
    filter_by_project =
      if is_nil(options.project_id),
        do: true,
        else: dynamic([s], s.base_project_id == ^options.project_id)

    filter_by_status =
      if options.include_archived,
        do: dynamic([s], s.status in [:active, :archived]),
        else: dynamic([s], s.status == :active)

    Section
    |> where([s], s.type == :blueprint)
    |> where(^filter_by_project)
    |> where(^filter_by_status)
    |> preload([:base_project])
    |> Repo.all()
  end

  @doc """
  Fetches and filters section records based on various parameters.

  This function retrieves section records, optionally filtering them based on paging, sorting, and text search criteria.

  ## Parameters

  - `%Paging{offset: offset, limit: limit}` (Paging struct): Specifies the limit and offset for paging the results.
  - `%Sorting{direction: direction, field: field}` (Sorting struct): Specifies the sorting direction and field for ordering the results.
  - `opts` (Keyword list, optional): Additional options, including `:project_id`, `:include_archived`, and `:text_search` for filtering.

  ## Returns

  A list of section records matching the specified criteria.

  ## Examples

  iex> browse(%Paging{offset: 0, limit: 10}, %Sorting{direction: :asc, field: :title}, [project_id: 1234, include_archived: false, text_search: "example"])
  [%Section{}, %Section{}, ...]
  """
  def browse(
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: direction, field: field},
        opts \\ []
      ) do
    filter_by_project =
      case opts[:project_id] do
        nil -> true
        project_id -> dynamic([s, _], s.base_project_id == ^project_id)
      end

    filter_by_status =
      if opts[:include_archived],
        do: dynamic([s, _], s.status in [:active, :archived]),
        else: dynamic([s, _], s.status == :active)

    filter_by_text =
      case opts[:text_search] do
        "" ->
          true

        text_search ->
          dynamic(
            [s, bp],
            fragment(
              """
              ((? ILIKE ?) OR (? ILIKE ?) OR (? AND ? ->> 'amount' ILIKE ?))
              """,
              s.title,
              ^"%#{text_search}%",
              bp.title,
              ^"%#{text_search}%",
              s.requires_payment,
              s.amount,
              ^"#{text_search}%"
            )
          )
      end

    query =
      Section
      |> join(:inner, [s], bp in Project, on: s.base_project_id == bp.id)
      |> preload([s, bp], base_project: bp)
      |> where([s, _], s.type == :blueprint)
      |> where(^filter_by_text)
      |> where(^filter_by_project)
      |> where(^filter_by_status)
      |> limit(^limit)
      |> offset(^offset)
      |> select([s, _bp], %{s | total_count: fragment("count(*) OVER()")})

    query =
      case field do
        :base_project_id ->
          order_by(
            query,
            [s, bp],
            [{^direction, bp.title}]
          )

        :requires_payment ->
          order_by(
            query,
            [s, _],
            {^direction,
             fragment(
               """
                 CASE
                   WHEN ? THEN COALESCE(? ->> 'amount', 'Yes')
                   ELSE 'None'
                 END
               """,
               s.requires_payment,
               s.amount
             )}
          )

        _ ->
          order_by(query, [p, _, _, _], {^direction, field(p, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Get all the products that are not associated within a community.

  ## Examples

      iex> list_products_not_in_community(1)
      {:ok, [%Section{}, ,...]}

      iex> list_products_not_in_community(123)
      {:ok, []}
  """
  def list_products_not_in_community(community_id) do
    from(
      section in Section,
      left_join: community_visibility in CommunityVisibility,
      on:
        section.id ==
          community_visibility.section_id and community_visibility.community_id == ^community_id,
      where:
        is_nil(community_visibility.id) and section.type == :blueprint and
          section.status == :active,
      select: section
    )
    |> Repo.all()
  end
end
