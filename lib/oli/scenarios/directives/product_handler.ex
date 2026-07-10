defmodule Oli.Scenarios.Directives.ProductHandler do
  @moduledoc """
  Handles product directives for creating products (blueprints) from projects.
  Products are templates that can be used to create course sections.
  """

  alias Oli.Scenarios.DirectiveTypes.{ProductDirective, ExecutionState}
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing

  def handle(
        %ProductDirective{
          name: name,
          title: title,
          from: from
        } = directive,
        %ExecutionState{} = state
      ) do
    with source_project when not is_nil(source_project) <- Engine.get_project(state, from),
         _publication <- ensure_publication(source_project, state),
         customizations <- extract_customizations(source_project),
         {:ok, blueprint} <-
           Blueprint.create_blueprint(
             source_project.project.slug,
             title || name,
             customizations,
             nil,
             build_blueprint_attrs(directive)
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

  defp build_blueprint_attrs(directive) do
    %{}
    |> maybe_put("requires_payment", directive.requires_payment)
    |> maybe_put(
      "payment_options",
      directive.payment_options && Atom.to_string(directive.payment_options)
    )
    |> maybe_put("pay_by_institution", directive.pay_by_institution)
    |> maybe_put("amount", directive.amount)
    |> maybe_put("has_grace_period", directive.has_grace_period)
    |> maybe_put("grace_period_days", directive.grace_period_days)
    |> maybe_put(
      "grace_period_strategy",
      directive.grace_period_strategy && Atom.to_string(directive.grace_period_strategy)
    )
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)
end
