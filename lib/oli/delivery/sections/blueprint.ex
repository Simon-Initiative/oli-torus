defmodule Oli.Delivery.Sections.Blueprint do
  import Ecto.Query, warn: false

  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Course.ProjectVisibility
  alias Oli.Publishing.Publication
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Groups.CommunityVisibility
  alias Oli.Institutions.Institution
  alias Oli.Repo

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
  def create_blueprint(base_project_slug, title) do
    Repo.transaction(fn _ ->
      case Oli.Authoring.Course.get_project_by_slug(base_project_slug) do
        nil ->
          {:error, {:invalid_project}}

        project ->
          now = DateTime.utc_now()

          new_blueprint = %{
            "type" => :blueprint,
            "status" => :active,
            "base_project_id" => project.id,
            "open_and_free" => false,
            "context_id" => UUID.uuid4(),
            "start_date" => now,
            "end_date" => now,
            "title" => title,
            "requires_payment" => false,
            "registration_open" => false,
            "timezone" => "America/New_York",
            "grace_period_days" => 1,
            "amount" => Money.new(:USD, "25.00")
          }

          case Sections.create_section(new_blueprint) do
            {:ok, blueprint} ->
              publication =
                Oli.Publishing.get_latest_published_publication_by_slug(base_project_slug)

              case Sections.create_section_resources(blueprint, publication) do
                {:ok, section} -> section
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
  """
  def duplicate(%Section{} = section, attrs \\ %{}) do
    Repo.transaction(fn _ ->
      with {:ok, blueprint} <- dupe_section(section, attrs),
           {:ok, _} <- dupe_section_project_publications(section, blueprint),
           {:ok, duplicated_root_resource} <- dupe_section_resources(section, blueprint),
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
          delivery_policy_id: nil
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
         %Section{} = blueprint
       ) do
    query =
      from(
        s in Oli.Delivery.Sections.SectionResource,
        where: s.section_id == ^id,
        select: s
      )

    resources = Repo.all(query)

    # First just duplicate the section resource records, wired to point
    # to the new blueprint record
    results =
      Enum.reverse(resources)
      |> Enum.reduce_while({:ok, []}, fn p, {:ok, all} ->
        attrs =
          Map.merge(Map.from_struct(p), %{
            section_id: blueprint.id
          })
          |> Map.delete(:id)

        case Sections.create_section_resource(attrs) do
          {:ok, copy} -> {:cont, {:ok, [copy | all]}}
          {:error, e} -> {:halt, {:error, e}}
        end
      end)

    # If the first step succeeded, make a second pass through to edit each
    # to update the id references in the :children list.  This two pass approach
    # avoids a more complicated single pass recursive approach.
    case results do
      {:ok, section_resources} ->
        resource_map =
          Enum.zip(resources, section_resources)
          |> Enum.reduce(%{}, fn {original, duplicate}, m ->
            Map.put(m, original.id, duplicate.id)
          end)

        Enum.reduce_while(section_resources, {:ok, nil}, fn p, {:ok, item} ->
          attrs = %{
            children: Enum.map(p.children, fn id -> Map.get(resource_map, id) end)
          }

          case Sections.update_section_resource(p, attrs) do
            {:ok, copy} ->
              # We want to keep track of, and eventually return the duplicated
              # root resource
              case Map.get(resource_map, root_id) == copy.id do
                true -> {:cont, {:ok, copy}}
                false -> {:cont, {:ok, item}}
              end

            {:error, e} ->
              {:halt, {:error, e}}
          end
        end)

      e ->
        e
    end
  end

  defp dupe_section_project_publications(%Section{id: id}, %Section{} = blueprint) do
    query =
      from(
        s in Oli.Delivery.Sections.SectionsProjectsPublications,
        where: s.section_id == ^id,
        select: s
      )

    Repo.all(query)
    |> Enum.reduce_while({:ok, []}, fn p, {:ok, all} ->
      attrs = %{
        section_id: blueprint.id,
        project_id: p.project_id,
        publication_id: p.publication_id
      }

      case Sections.create_section_project_publication(attrs) do
        {:ok, copy} -> {:cont, {:ok, [copy | all]}}
        {:error, e} -> {:halt, {:error, e}}
      end
    end)
  end

  def list_for_project(%Project{id: id}) do
    query =
      from(
        s in Section,
        where: s.type == :blueprint and s.base_project_id == ^id,
        select: s,
        preload: [:base_project]
      )

    Repo.all(query)
  end

  def list() do
    query =
      from(
        s in Section,
        where: s.type == :blueprint,
        select: s,
        preload: [:base_project]
      )

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
