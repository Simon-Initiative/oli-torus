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
    with source_project when not is_nil(source_project) <- Engine.get_project(state, from),
         _publication <- ensure_publication(source_project, state),
         customizations <- extract_customizations(source_project),
         {:ok, blueprint} <-
           Blueprint.create_blueprint(
             source_project.project.slug,
             title || name,
             customizations
           ) do
      # Store the product in state
      updated_state = Engine.put_product(state, name, blueprint)
      {:ok, updated_state}
    else
      nil ->
        {:error, "Project '#{from}' not found"}

      {:error, reason} ->
        {:error, "Failed to create product '#{name}': #{inspect(reason)}"}
    end
  end

  defp ensure_publication(source_project, state) do
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
  end

  defp extract_customizations(source_project) do
    case source_project.project.customizations do
      nil -> nil
      labels -> Map.from_struct(labels)
    end
  end
end
