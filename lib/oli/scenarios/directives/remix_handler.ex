defmodule Oli.Scenarios.Directives.RemixHandler do
  @moduledoc """
  Handles remix directives for copying content from projects into sections.
  Remixes content from a source project into a target section's hierarchy.
  """

  alias Oli.Scenarios.DirectiveTypes.RemixDirective
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Delivery.Remix
  alias Oli.Delivery.Remix

  def handle(
        %RemixDirective{
          from: from,
          from_product: from_product,
          user: user_name,
          resource: resource_title,
          section: section_name,
          to: to
        },
        %ExecutionState{} = state
      ) do
    try do
      if from_product,
        do: remix_from_product(state, from_product, user_name, resource_title, section_name, to),
        else: remix_from_project(state, from, resource_title, section_name, to)
    rescue
      e ->
        {:error,
         "Failed to remix '#{resource_title}' into '#{section_name}': #{Exception.message(e)}"}
    end
  end

  defp remix_from_project(state, from, resource_title, section_name, to) do
    source_project =
      Engine.get_project(state, from) ||
        raise "Source project '#{from}' not found"

    # Get the target section or product
    section =
      case Engine.get_product(state, section_name) do
        nil ->
          Engine.get_section(state, section_name) ||
            raise "Section or product '#{section_name}' not found"

        product ->
          product
      end

    # Get the resource ID to remix from the source project
    resource_id =
      source_project.id_by_title[resource_title] ||
        raise "Resource '#{resource_title}' not found in source project '#{from}'"

    # Get the latest published publication for the source project
    publication =
      case Publishing.get_latest_published_publication_by_slug(source_project.project.slug) do
        nil ->
          # If no published publication exists, publish one
          {:ok, pub} =
            Publishing.publish_project(
              source_project.project,
              "Auto-published for remix",
              state.current_author.id
            )

          pub

        pub ->
          pub
      end

    # Initialize Remix state (auth-agnostic; assume current_author is authorized)
    {:ok, remix_state} = Remix.init(section, state.current_author)

    # Select target container
    remix_state =
      case to do
        "root" ->
          remix_state

        _ ->
          node = find_node_by_title(remix_state.hierarchy, to)
          if node == nil, do: raise("Target container '#{to}' not found in section hierarchy")
          {:ok, remix_state} = Remix.select_active(remix_state, node.uuid)
          remix_state
      end

    # Get published resources for this publication
    published_resources_by_resource_id =
      Publishing.get_published_resources_for_publications([publication.id])

    # Create selection tuple like RemixUI does
    selection = [{publication.id, resource_id}]

    # Use Remix.add_materials to update state
    {:ok, remix_state} =
      Remix.add_materials(remix_state, selection, published_resources_by_resource_id)

    # Persist via Remix.save/2
    {:ok, refreshed_section} = Remix.save(remix_state, state.current_author)

    # Update state with the refreshed section or product
    updated_state =
      case Engine.get_product(state, section_name) do
        nil ->
          # It's a section
          Engine.put_section(state, section_name, refreshed_section)

        _product ->
          # It's a product - update as product
          Engine.put_product(state, section_name, refreshed_section)
      end

    {:ok, updated_state}
  end

  defp remix_from_product(state, product_name, user_name, resource_title, section_name, to) do
    section =
      Engine.get_section(state, section_name) || raise "Section '#{section_name}' not found"

    product =
      Engine.get_product(state, product_name) || raise "Product '#{product_name}' not found"

    user = Engine.get_user(state, user_name) |> Repo.preload(:author)
    {:ok, remix_state} = Remix.init(section, user)

    source =
      Enum.find(
        remix_state.available_sources,
        &(&1.type == :product and &1.product_id == product.id)
      ) || raise "Product source '#{product_name}' is unavailable"

    {:ok, _source, hierarchy} = Remix.source_hierarchy(source.key, remix_state)

    node =
      find_node_by_title(hierarchy, resource_title) ||
        raise "Resource '#{resource_title}' not found"

    {:ok, selection} = Remix.selection_tuple(source, node)

    {:ok, remix_state} =
      if to == "root",
        do: {:ok, remix_state},
        else:
          Remix.select_active(
            remix_state,
            (find_node_by_title(remix_state.hierarchy, to) ||
               raise("Target container '#{to}' not found")).uuid
          )

    {:ok, remix_state} = Remix.add_materials(remix_state, [selection])
    {:ok, refreshed_section} = Remix.save(remix_state, state.current_author)
    {:ok, Engine.put_section(state, section_name, refreshed_section)}
  end

  defp find_node_by_title(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, title) do
    if node.revision && node.revision.title == title do
      node
    else
      Enum.find_value(node.children || [], fn child ->
        find_node_by_title(child, title)
      end)
    end
  end

  defp find_node_by_title(_, _), do: nil
end
