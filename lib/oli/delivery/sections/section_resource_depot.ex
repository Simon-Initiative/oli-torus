defmodule Oli.Delivery.Sections.SectionResourceDepot do
  @moduledoc """
  This module provides a data store for cached section resource records.

  It largely delegates to the more generic Depot module, but layers on top of
  it SectionResource specific logic. In this manner, we can have client
  code use the SectionResourceDepot module without needing to know the underlying
  implementation details (such as the Depot query syntax).

  Any client code that is making changes to SectionResource records must
  be calling the DepotCoordinator module to ensure that (potentially distributed)
  caches are invalidated.  This module is only for reading data.

  Note: only containers, pages and objectives are included in the SectionResourceCache at the moment. There just wasn't a need yet to include activities and tags or any other resource type.
  """

  import Ecto.Query
  alias Oli.Delivery.Depot
  alias Oli.Delivery.Depot.DepotDesc
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.Repo

  @depot_desc %DepotDesc{
    name: "SectionResource",
    schema: SectionResource,
    table_name_prefix: :section_resources,
    key_field: :resource_id,
    table_id_field: :section_id
  }

  def depot_desc(), do: @depot_desc

  @doc """
  Retrieve the full hierarchy of section resources for a given section.

  Usefull for generating a full hierarchy of section resources for a section,
  in places where code had been calling Oli.Delivery.Hierarchy.full_hierarchy
  directly.
  """
  def get_full_hierarchy(%Section{} = section) do
    init_if_necessary(section.id)

    page = Oli.Resources.ResourceType.id_for_page()
    container = Oli.Resources.ResourceType.id_for_container()

    srs = Depot.query(@depot_desc, section.id, [{:resource_type_id, {:in, [page, container]}}])
    Oli.Delivery.Hierarchy.full_hierarchy(section, srs)
  end

  @doc """
  Retrieve the full hierarchy of section resources for a given section as would
  the DeliveryResolver.

  Usefull for generating a full hierarchy of section resources for a section,
  in places where code had been calling Oli.Publishing.DeliveryResolver.full_hierarchy
  directly.
  """
  def get_delivery_resolver_full_hierarchy(%Section{} = section) do
    init_if_necessary(section.id)

    page = Oli.Resources.ResourceType.id_for_page()
    container = Oli.Resources.ResourceType.id_for_container()

    srs = Depot.query(@depot_desc, section.id, [{:resource_type_id, {:in, [page, container]}}])
    Oli.Publishing.DeliveryResolver.full_hierarchy(section, srs)
  end

  @doc """
  Returns a list of SectionResource records for all graded pages for a given section.

  An optional keyword list can be passed to extend the filtering conditions.

  Example:
    SectionResourceDepot.graded_pages(some_section_id, [hidden: false])
  """
  def graded_pages(section_id, additional_query_conditions \\ []) do
    init_if_necessary(section_id)

    page = Oli.Resources.ResourceType.id_for_page()

    query_conditions =
      Keyword.merge([graded: true, resource_type_id: page], additional_query_conditions)

    Depot.query(
      @depot_desc,
      section_id,
      query_conditions
    )
    |> Enum.sort_by(& &1.numbering_index)
  end

  @doc """
  Access the SectionResource records pertaining to the course schedule.
  """
  def retrieve_schedule(section_id, filter_resource_type \\ false) do
    init_if_necessary(section_id)

    page_type_id = Oli.Resources.ResourceType.id_for_page()
    container_type_id = Oli.Resources.ResourceType.id_for_container()

    filter_by_resource_type =
      case filter_resource_type do
        :pages ->
          [{:resource_type_id, {:==, page_type_id}}]

        :containers ->
          [{:resource_type_id, {:==, container_type_id}}]

        _ ->
          [{:resource_type_id, {:in, [container_type_id, page_type_id]}}]
      end

    Depot.query(@depot_desc, section_id, filter_by_resource_type)
  end

  @doc """
  Returns a list of SectionResource pages (graded + ungraded) for a given section.
  An optional parameter `graded_only` can be passed to filter only graded pages.
  """
  def get_lessons(section, graded_only \\ false) do
    init_if_necessary(section.id)

    page_type_id = Oli.Resources.ResourceType.id_for_page()

    conditions =
      case graded_only do
        true -> [resource_type_id: page_type_id, graded: true, hidden: false]
        false -> [resource_type_id: page_type_id, hidden: false]
      end

    Depot.query(@depot_desc, section.id, conditions)
  end

  @doc """
  Returns a list of SectionResource records filtered by type ids for a given section.
  """
  def get_section_resources_by_type_ids(section_id, type_ids) do
    init_if_necessary(section_id)
    Depot.query(@depot_desc, section_id, [{:resource_type_id, {:in, type_ids}}])
  end

  defp init_if_necessary(section_id) do
    if Depot.table_exists?(@depot_desc, section_id) do
      {:ok, :exists}
    else
      if SectionResourceMigration.requires_migration?(section_id) do
        SectionResourceMigration.migrate(section_id)
      end

      Depot.create_table(@depot_desc, section_id)
      load(section_id)

      {:ok, :created}
    end
  end

  defp load(section_id) do
    page = Oli.Resources.ResourceType.id_for_page()
    container = Oli.Resources.ResourceType.id_for_container()
    objective = Oli.Resources.ResourceType.id_for_objective()

    query =
      from sr in SectionResource,
        where:
          sr.section_id == ^section_id and sr.resource_type_id in [^page, ^container, ^objective],
        select: sr

    results = Repo.all(query)

    Depot.clear_and_set(@depot_desc, section_id, results)
  end
end
