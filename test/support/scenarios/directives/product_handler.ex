defmodule Oli.Scenarios.Directives.ProductHandler do
  @moduledoc """
  Handles product directives for creating products (blueprints) from projects.
  Products are templates that can be used to create course sections.
  """

  alias Oli.Scenarios.DirectiveTypes.{ProductDirective, ExecutionState}
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing

  def handle(%ProductDirective{name: name, title: title, from: from}, %ExecutionState{} = state) do
    # Get the source project
    case Engine.get_project(state, from) do
      nil ->
        {:error, "Project '#{from}' not found"}

      source_project ->
        # Ensure the project has a published publication
        _publication =
          case Publishing.get_latest_published_publication_by_slug(source_project.project.slug) do
            nil ->
              # Create initial publication
              {:ok, pub} =
                Publishing.publish_project(
                  source_project.project,
                  "Initial publication for product",
                  state.current_author.id
                )

              pub

            pub ->
              pub
          end

        # Get customizations from the project if any
        customizations =
          case source_project.project.customizations do
            nil -> nil
            labels -> Map.from_struct(labels)
          end

        # Create the product/blueprint
        case Blueprint.create_blueprint(
               source_project.project.slug,
               title || name,
               customizations
             ) do
          {:ok, blueprint} ->
            # Store the product in state
            updated_state = Engine.put_product(state, name, blueprint)
            {:ok, updated_state}

          {:error, reason} ->
            {:error, "Failed to create product '#{name}': #{inspect(reason)}"}
        end
    end
  end
end
