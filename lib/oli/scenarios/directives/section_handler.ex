defmodule Oli.Scenarios.Directives.SectionHandler do
  @moduledoc """
  Handles section creation directives.
  """

  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Scenarios.DirectiveTypes.SectionDirective
  alias Oli.Scenarios.Directives.DirectiveAttrs
  alias Oli.Scenarios.Engine

  def handle(%SectionDirective{name: name, title: title, from: from} = directive, state) do
    try do
      directive_attrs =
        directive
        |> Map.from_struct()
        |> Map.put(:title, title || name)

      section =
        if from do
          # Create section from an existing project or product.
          create_from_source(from, directive_attrs, state)
        else
          # Create a standalone section with an auto-generated backing project.
          create_standalone(directive_attrs, state)
        end

      {:ok, Engine.put_section(state, name, section)}
    rescue
      e ->
        {:error, "Failed to create section '#{name}': #{Exception.message(e)}"}
    end
  end

  defp create_from_source(source_name, directive_attrs, state) do
    case Engine.get_product(state, source_name) do
      nil ->
        # Not a product, so resolve the source as a project.
        case Engine.get_project(state, source_name) do
          nil -> raise "Project or product '#{source_name}' not found"
          built_project -> create_from_built_project(built_project, directive_attrs, state)
        end

      product ->
        # Create section from product/blueprint using the duplication flow.
        create_from_product(product, directive_attrs, state)
    end
  end

  defp create_from_built_project(built_project, directive_attrs, state) do
    # Reuse the latest publication, creating an initial one if the project has not been published yet.
    publication =
      case Publishing.get_latest_published_publication_by_slug(built_project.project.slug) do
        nil ->
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

    attrs =
      directive_attrs
      |> base_section_attrs(state)
      |> Map.put(:base_project_id, built_project.project.id)

    {:ok, section} = Sections.create_section(attrs)
    {:ok, section} = Sections.create_section_resources(section, publication)
    section
  end

  defp create_from_product(product, directive_attrs, state) do
    section_params =
      directive_attrs
      |> base_section_attrs(state)
      |> Map.put(:blueprint_id, product.id)

    {:ok, section} = Delivery.create_from_product(state.current_author, product, section_params)
    Oli.Repo.preload(section, [:blueprint])
  end

  defp create_standalone(directive_attrs, state) do
    title = directive_attrs.title

    # Standalone sections still need a backing project/publication for section resources.
    {:ok, project} =
      Oli.Authoring.Course.create_project(%{
        title: "#{title} Project",
        description: "Auto-generated project for section #{title}",
        authors: [state.current_author]
      })

    {:ok, publication} =
      Publishing.publish_project(
        project,
        "initial",
        state.current_author.id
      )

    section_attrs =
      directive_attrs
      |> base_section_attrs(state)
      |> Map.put(:base_project_id, project.id)

    {:ok, section} = Sections.create_section(section_attrs)
    {:ok, section} = Sections.create_section_resources(section, publication)
    section
  end

  defp base_section_attrs(directive_attrs, state) do
    directive_attrs
    |> DirectiveAttrs.section_attrs()
    |> Map.merge(%{
      context_id: "context_#{System.unique_integer([:positive])}",
      institution_id: state.current_institution.id
    })
  end
end
