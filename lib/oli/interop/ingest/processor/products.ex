defmodule Oli.Interop.Ingest.Processor.Products do
  alias Oli.Interop.Ingest.State
  alias Oli.Publishing.ChangeTracker

  def process(
        %State{
          products: products,
          project: project
        } = state
      ) do
    State.notify_step_start(state, :products)

    result =
      case products do
        [] ->
          {:ok, state}

        _ ->
          # Products can only be created with the project published, so do that first
          Oli.Publishing.publish_project(project, "Initial publication", state.author.id)

          # Create each product, all the while tracking any newly created containers in the container map
          Enum.reduce_while(products, {:ok, state}, fn {_, product}, {:ok, state} ->
            case create_product(state, product) do
              {:ok, state} -> {:cont, {:ok, state}}
              {:error, e} -> {:halt, {:error, e}}
            end
          end)
      end

    case result do
      {:ok, state} -> state
      {:error, e} -> %{state | force_rollback: e}
    end
  end

  defp create_product(
         %State{
           root_revision: root_revision,
           legacy_to_resource_id_map: legacy_to_resource_id_map,
           container_id_map: container_id_map,
           project: project,
           author: author
         } = state,
         product
       ) do
    hierarchy_definition = Map.put(%{}, root_revision.resource_id, [])

    original_container_count = Map.keys(container_id_map) |> Enum.count()

    # Recursive processing to track new containers and build the hierarchy definition
    {container_id_map, hierarchy_definition} =
      Map.get(product, "children")
      |> Enum.filter(fn c -> c["type"] == "item" || c["type"] == "container" end)
      |> Enum.reduce({container_id_map, hierarchy_definition}, fn item,
                                                                  {container_id_map,
                                                                   hierarchy_definition} ->
        process_product_item(
          root_revision.resource_id,
          hierarchy_definition,
          project,
          item,
          container_id_map,
          legacy_to_resource_id_map,
          author
        )
      end)

    # If any new containers were created, we have to publish again so that the product can pin
    # a published version of this new container as a section resource
    if Map.keys(container_id_map) |> Enum.count() != original_container_count do
      Oli.Publishing.publish_project(project, "New containers for product", author.id)
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
      "amount" => Map.get(product, "amount")
    }

    # Create the blueprint (aka 'product'), with the hierarchy definition that was just built
    # to mirror the product JSON.
    case Oli.Delivery.Sections.Blueprint.create_blueprint(
           project.slug,
           product["title"],
           custom_labels,
           hierarchy_definition,
           new_product_attrs
         ) do
      {:ok, _} -> {:ok, %{state | container_id_map: container_id_map}}
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
        id = Map.get(page_map, Map.get(item, "idref"))

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
                intro_content: Map.get(item, "intro_content", %{}),
                intro_video: Map.get(item, "intro_video"),
                poster_image: Map.get(item, "poster_image"),
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
end
