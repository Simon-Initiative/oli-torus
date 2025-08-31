defmodule Oli.Scenarios.Directives.SectionHandler do
  @moduledoc """
  Handles section creation directives.
  """

  alias Oli.Scenarios.DirectiveTypes.SectionDirective
  alias Oli.Scenarios.Engine
  alias Oli.Publishing
  alias Oli.Delivery
  alias Oli.Delivery.Sections

  def handle(
        %SectionDirective{
          name: name,
          title: title,
          from: from,
          type: type,
          registration_open: reg_open
        },
        state
      ) do
    try do
      section =
        if from do
          # Create section from an existing project
          create_from_project(from, title || name, type, reg_open, state)
        else
          # Create standalone section (empty)
          create_standalone(title || name, type, reg_open, state)
        end

      # Store the section in state
      new_state = Engine.put_section(state, name, section)

      {:ok, new_state}
    rescue
      e ->
        {:error, "Failed to create section '#{name}': #{Exception.message(e)}"}
    end
  end

  defp create_from_project(source_name, title, type, reg_open, state) do
    # First check if it's a product
    case Engine.get_product(state, source_name) do
      nil ->
        # Not a product, check if it's a project
        case Engine.get_project(state, source_name) do
          nil ->
            raise "Project or product '#{source_name}' not found"

          built_project ->
            create_from_built_project(built_project, title, type, reg_open, state)
        end

      product ->
        # Create section from product/blueprint
        create_from_product(product, title, type, reg_open, state)
    end
  end

  defp create_from_built_project(built_project, title, type, reg_open, state) do
        # Get the latest published publication or create one
        publication =
          case Publishing.get_latest_published_publication_by_slug(built_project.project.slug) do
            nil ->
              # Create initial publication
              {:ok, pub} =
                Publishing.publish_project(
                  built_project.project,
                  "initial",
                  state.current_author.id
                )

              pub

            pub ->
              pub
          end

        # Create section
        {:ok, section} =
          Sections.create_section(%{
            title: title,
            registration_open: reg_open,
            context_id: "context_#{System.unique_integer([:positive])}",
            institution_id: state.current_institution.id,
            base_project_id: built_project.project.id,
            type: type || :enrollable
          })

        # Create section resources from publication
        {:ok, section} = Sections.create_section_resources(section, publication)

        section
  end

  defp create_from_product(product, title, type, reg_open, state) do
    # Create section from blueprint/product using the proper Delivery function
    section_params = %{
      title: title,
      registration_open: reg_open,
      context_id: "context_#{System.unique_integer([:positive])}",
      institution_id: state.current_institution.id,
      type: type || :enrollable
    }

    {:ok, section} = Delivery.create_from_product(state.current_author, product, section_params)
    
    section
  end

  defp create_standalone(title, type, reg_open, state) do
    # Create a minimal project first
    {:ok, project} =
      Oli.Authoring.Course.create_project(%{
        title: "#{title} Project",
        description: "Auto-generated project for section #{title}",
        authors: [state.current_author]
      })

    # Publish it
    {:ok, publication} =
      Publishing.publish_project(
        project,
        "initial",
        state.current_author.id
      )

    # Create section
    {:ok, section} =
      Sections.create_section(%{
        title: title,
        registration_open: reg_open,
        context_id: "context_#{System.unique_integer([:positive])}",
        institution_id: state.current_institution.id,
        base_project_id: project.id,
        type: type || :enrollable
      })

    # Create section resources
    {:ok, section} = Sections.create_section_resources(section, publication)

    section
  end
end
