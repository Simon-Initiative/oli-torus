defmodule Oli.Scenarios.Directives.UpdateHandler do
  @moduledoc """
  Handles update directives to apply publication updates to sections.
  """

  alias Oli.Scenarios.DirectiveTypes.UpdateDirective
  alias Oli.Scenarios.Engine

  def handle(%UpdateDirective{from: project_name, to: target_name}, state) do
    try do
      # First check if target is a product
      product = Engine.get_product(state, target_name)
      
      if product != nil do
        # Handle product update
        handle_product_update(project_name, target_name, product, state)
      else
        # Handle section update (existing logic)
        handle_section_update(project_name, target_name, state)
      end
    rescue
      e ->
        {:error,
         "Failed to apply update from '#{project_name}' to '#{target_name}': #{Exception.message(e)}"}
    end
  end

  defp handle_product_update(project_name, product_name, product, state) do
    # Get the project
    built_project =
      Engine.get_project(state, project_name) ||
        raise "Project '#{project_name}' not found"

    # Get the latest published publication for this project
    latest_publication =
      Oli.Publishing.get_latest_published_publication_by_slug(built_project.project.slug)

    if is_nil(latest_publication) do
      raise "No published publications found for project '#{project_name}'"
    end

    # Verify the product is from this project
    if product.base_project_id != built_project.project.id do
      raise "Product '#{product_name}' is not based on project '#{project_name}'"
    end

    # Apply the publication update to the product (which is actually a Section with type :blueprint)
    result =
      Oli.Delivery.Sections.Updates.apply_publication_update(product, latest_publication.id)

    # Check if result looks like an error
    case result do
      {:error, reason} ->
        raise "Failed to apply update: #{inspect(reason)}"

      {:ok, updated_product} ->
        refreshed_product = Oli.Delivery.Sections.get_section!(updated_product.id)

        # Update the product in state with the refreshed product
        updated_state = Engine.put_product(state, product_name, refreshed_product)
        {:ok, updated_state}

      _ ->
        updated_product = Oli.Delivery.Sections.get_section!(product.id)

        updated_state = Engine.put_product(state, product_name, updated_product)
        {:ok, updated_state}
    end
  end

  defp handle_section_update(project_name, section_name, state) do
    # Get the section
    section =
      Engine.get_section(state, section_name) ||
        raise "Section '#{section_name}' not found"

    # Get the project
    built_project =
      Engine.get_project(state, project_name) ||
        raise "Project '#{project_name}' not found"

    # Get the latest published publication for this project
    latest_publication =
      Oli.Publishing.get_latest_published_publication_by_slug(built_project.project.slug)

    if is_nil(latest_publication) do
      raise "No published publications found for project '#{project_name}'"
    end

    # Verify the section is from this project
    if section.base_project_id != built_project.project.id do
      raise "Section '#{section_name}' is not based on project '#{project_name}'"
    end

    # Apply the publication update to the section
    result =
      Oli.Delivery.Sections.Updates.apply_publication_update(section, latest_publication.id)

    # Check if result looks like an error
    case result do
      {:error, reason} ->
        raise "Failed to apply update: #{inspect(reason)}"

      {:ok, updated_section} ->
        refreshed_section = Oli.Delivery.Sections.get_section!(updated_section.id)

        # Update the section in state with the refreshed section
        updated_state = Engine.put_section(state, section_name, refreshed_section)
        {:ok, updated_state}

      _ ->
        updated_section = Oli.Delivery.Sections.get_section!(section.id)

        updated_state = Engine.put_section(state, section_name, updated_section)
        {:ok, updated_state}
    end
  end
end
