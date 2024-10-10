defmodule Oli.Delivery.Sections.SectionResourceDepot do

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

  def get_full_hierarchy(%Section{} = section) do
    init_if_necessary(section.id)

    page = Oli.Resources.ResourceType.id_for_page()
    container = Oli.Resources.ResourceType.id_for_container()

    srs = Depot.query(@depot_desc, section.id, [{:resource_type_id, :in, [page, container]}])
    Oli.Delivery.Hierarchy.full_hierarchy(section, srs)
  end

  def get_delivery_resolver_full_hierarchy(%Section{} = section) do
    init_if_necessary(section.id)

    page = Oli.Resources.ResourceType.id_for_page()
    container = Oli.Resources.ResourceType.id_for_container()

    srs = Depot.query(@depot_desc, section.id, [{:resource_type_id, :in, [page, container]}])
    Oli.Publishing.DeliveryResolver.full_hierarchy(section, srs)
  end

  def graded_pages(section_id) do
    init_if_necessary(section_id)

    page = Oli.Resources.ResourceType.id_for_page()
    Depot.query(@depot_desc, section_id, graded: true, resource_type_id: page)
    |> Enum.sort_by(&(&1.numbering_index))
  end

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

  def get_lessons(section, graded_only) do
    init_if_necessary(section.id)

    page_type_id = Oli.Resources.ResourceType.id_for_page()

    conditions = case graded_only do
      true  -> [resource_type_id: page_type_id, graded: true, hidden: false]
      false  -> [resource_type_id: page_type_id, hidden: false]
    end

    Depot.query(@depot_desc, section.id, conditions)

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

    query = from sr in SectionResource,
            where: sr.section_id == ^section_id and sr.resource_type_id in [^page, ^container, ^objective],
            select: sr

    results = Repo.all(query)

    Depot.clear_and_set(@depot_desc, section_id, results)
  end

end
