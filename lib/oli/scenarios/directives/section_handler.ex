defmodule Oli.Scenarios.Directives.SectionHandler do
  @moduledoc """
  Handles section creation directives.

  A section may also select a named GenAI service configuration for Dot. This
  creates a section-specific `:student_dialogue` feature configuration after
  the section itself has been persisted.
  """

  alias Oli.Delivery
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Sections
  alias Oli.GenAI
  alias Oli.GenAI.Completions.ServiceConfig
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.SectionDirective
  alias Oli.Scenarios.Directives.DirectiveAttrs
  alias Oli.Scenarios.Engine

  def handle(%SectionDirective{name: name, title: title, from: from} = directive, state) do
    try do
      assistant_service = resolve_assistant_service!(directive)

      directive_attrs =
        directive
        |> Map.from_struct()
        |> Map.put(:title, title || name)

      section =
        create_section_with_assistant(
          from,
          directive_attrs,
          state,
          assistant_service
        )

      {:ok, Engine.put_section(state, name, section)}
    rescue
      e ->
        {:error, "Failed to create section '#{name}': #{Exception.message(e)}"}
    end
  end

  defp create_section_with_assistant(from, directive_attrs, state, nil) do
    create_section(from, directive_attrs, state)
  end

  defp create_section_with_assistant(from, directive_attrs, state, assistant_service) do
    case Repo.transaction(fn ->
           section = create_section(from, directive_attrs, state)
           configure_assistant_service(section, assistant_service)
         end) do
      {:ok, section} ->
        section

      {:error, {:assistant_configuration_failed, changeset}} ->
        raise "Failed to configure Dot service: #{inspect(changeset.errors)}"

      {:error, reason} ->
        raise "Section transaction failed: #{inspect(reason)}"
    end
  end

  # Create a standalone section with an auto-generated backing project.
  defp create_section(nil, directive_attrs, state),
    do: create_standalone(directive_attrs, state)

  # Create a section from an existing project or product.
  defp create_section(source, directive_attrs, state),
    do: create_from_source(source, directive_attrs, state)

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

  defp institution_for_section(%{institution: nil}, state), do: state.current_institution

  defp institution_for_section(%{institution: institution_name}, state) do
    case Engine.get_institution(state, institution_name) do
      nil -> raise "Institution '#{institution_name}' not found"
      institution -> institution
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
    institution = institution_for_section(directive_attrs, state)

    {amount, requires_payment} =
      case Paywall.section_cost_from_product(product, institution) do
        {:ok, nil} -> {product.amount, false}
        {:ok, amount} -> {amount, product.requires_payment}
        _ -> {product.amount, product.requires_payment}
      end

    section_params =
      directive_attrs
      |> base_section_attrs(state)
      |> Map.put(:amount, amount)
      |> Map.put(:requires_payment, requires_payment)
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
    institution = institution_for_section(directive_attrs, state)

    directive_attrs
    |> DirectiveAttrs.section_attrs()
    |> Map.merge(%{
      context_id: "context_#{System.unique_integer([:positive])}",
      institution_id: institution.id
    })
  end

  defp configure_assistant_service(section, nil),
    do: section

  defp configure_assistant_service(section, %ServiceConfig{id: service_config_id}) do
    attrs = %{
      feature: :student_dialogue,
      section_id: section.id,
      service_config_id: service_config_id
    }

    case GenAI.create_feature_config(attrs) do
      {:ok, _feature_config} -> section
      {:error, changeset} -> Repo.rollback({:assistant_configuration_failed, changeset})
    end
  end

  defp resolve_assistant_service!(%SectionDirective{assistant_service_config: nil}), do: nil

  defp resolve_assistant_service!(%SectionDirective{
         assistant_enabled: true,
         assistant_service_config: service_name
       }) do
    Repo.get_by(ServiceConfig, name: service_name) ||
      raise "GenAI service config '#{service_name}' not found"
  end

  defp resolve_assistant_service!(%SectionDirective{assistant_service_config: service_name}) do
    raise "assistant_service_config '#{service_name}' requires assistant_enabled: true"
  end
end
