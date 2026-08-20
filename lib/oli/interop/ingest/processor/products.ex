defmodule Oli.Interop.Ingest.Processor.Products do
  alias Oli.Interop.Ingest.State
  alias Oli.Publishing.ChangeTracker
  alias Oli.LearningModel.ModelVersion
  alias Oli.Repo

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
          Enum.reduce_while(products, {:ok, state}, fn {archive_id, product}, {:ok, state} ->
            case create_product(state, archive_id, product) do
              {:ok, state} -> {:cont, {:ok, state}}
              {:error, e} -> {:halt, {:error, e}}
            end
          end)
      end

    case result do
      {:ok, state} ->
        state

      {:error, e} ->
        error_state = %{state | errors: [e | state.errors]}
        Repo.rollback(error_state)
    end
  end

  defp create_product(%State{project: project} = state, archive_id, product) do
    case ModelVersion.decode_archive(
           Map.get(product, "learningModelVersion"),
           project.learning_model_version
         ) do
      {:ok, learning_model_version} ->
        do_create_product(state, product, learning_model_version)

      {:error, _reason} ->
        value = Map.get(product, "learningModelVersion")
        archive_file = State.archive_source_file(state, archive_id)

        {:error,
         "Invalid learningModelVersion in #{archive_file}.json: expected \"naive\", \"lkt_aoa\", or null; got #{inspect(value, limit: 3, printable_limit: 80)}"}
    end
  end

  defp do_create_product(
         %State{
           root_revision: root_revision,
           legacy_to_resource_id_map: legacy_to_resource_id_map,
           container_id_map: container_id_map,
           project: project,
           author: author
         } = state,
         product,
         learning_model_version
       ) do
    hierarchy_definition = Map.put(%{}, root_revision.resource_id, [])

    original_container_count = Map.keys(container_id_map) |> Enum.count()

    # Recursive processing to track new containers and build the hierarchy definition
    {container_id_map, hierarchy_definition} =
      Map.get(product, "children", [])
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
      Map.get(product, "children", [])
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
      "description" => Map.get(product, "description"),
      "welcome_title" => Map.get(product, "welcomeTitle"),
      "encouraging_subtitle" => Map.get(product, "encouragingSubtitle"),
      "requires_payment" => Map.get(product, "requiresPayment"),
      "payment_options" => Map.get(product, "paymentOptions"),
      "pay_by_institution" => Map.get(product, "payByInstitution"),
      "grace_period_days" => Map.get(product, "gracePeriodDays"),
      "amount" => Map.get(product, "amount"),
      "certificate_enabled" => Map.get(product, "certificateEnabled", false),
      "learning_model_version" => learning_model_version
    }

    {certificate_params, new_product_attrs} =
      case Map.get(product, "certificate") do
        cert when cert in [nil, "null"] ->
          {nil, new_product_attrs}

        cert ->
          assessments =
            Map.get(cert, "custom_assessments", [])
            |> Enum.map(fn v ->
              Map.get(legacy_to_resource_id_map, Integer.to_string(v))
            end)

          cert_params = Map.put(cert, "custom_assessments", assessments)
          product_attrs = Map.put(new_product_attrs, "certificate_enabled", true)
          {cert_params, product_attrs}
      end

    # Create the blueprint (aka 'product'), with the hierarchy definition that was just built
    # to mirror the product JSON.
    case Oli.Delivery.Sections.Blueprint.create_blueprint_from_archive(
           project.slug,
           product["title"],
           custom_labels,
           hierarchy_definition,
           new_product_attrs,
           learning_model_version
         ) do
      {:ok, blueprint} ->
        maybe_add_certificate(certificate_params, blueprint, %{
          state
          | container_id_map: container_id_map
        })

      e ->
        e
    end
  end

  defp maybe_add_certificate(nil, _blueprint, state), do: {:ok, state}

  defp maybe_add_certificate(certificate_params, blueprint, state) do
    certificate_params = Map.put(certificate_params, "section_id", blueprint.id)

    case Oli.Delivery.Certificates.create(certificate_params) do
      {:ok, _certificate} -> {:ok, state}
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
end
