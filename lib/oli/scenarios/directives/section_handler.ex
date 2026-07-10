defmodule Oli.Scenarios.Directives.SectionHandler do
  @moduledoc """
  Handles section creation directives.
  """

  alias Oli.Scenarios.DirectiveTypes.SectionDirective
  alias Oli.Scenarios.Engine
  alias Oli.Publishing
  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Money

  def handle(
        %SectionDirective{
          name: name,
          title: title,
          from: from,
          type: type,
          registration_open: reg_open,
          slug: slug,
          open_and_free: open_and_free,
          requires_enrollment: requires_enrollment,
          requires_payment: requires_payment,
          payment_options: payment_options,
          pay_by_institution: pay_by_institution,
          amount: amount,
          has_grace_period: has_grace_period,
          grace_period_days: grace_period_days,
          grace_period_strategy: grace_period_strategy,
          start_date: start_date,
          end_date: end_date
        },
        state
      ) do
    try do
      section =
        if from do
          # Create section from an existing project
          create_from_project(
            from,
            title || name,
            type,
            reg_open,
            slug,
            open_and_free,
            requires_enrollment,
            requires_payment,
            payment_options,
            pay_by_institution,
            amount,
            has_grace_period,
            grace_period_days,
            grace_period_strategy,
            start_date,
            end_date,
            state
          )
        else
          # Create standalone section (empty)
          create_standalone(
            title || name,
            type,
            reg_open,
            slug,
            open_and_free,
            requires_enrollment,
            requires_payment,
            payment_options,
            pay_by_institution,
            amount,
            has_grace_period,
            grace_period_days,
            grace_period_strategy,
            start_date,
            end_date,
            state
          )
        end

      # Store the section in state
      new_state = Engine.put_section(state, name, section)

      {:ok, new_state}
    rescue
      e ->
        {:error, "Failed to create section '#{name}': #{Exception.message(e)}"}
    end
  end

  defp create_from_project(
         source_name,
         title,
         type,
         reg_open,
         slug,
         open_and_free,
         requires_enrollment,
         requires_payment,
         payment_options,
         pay_by_institution,
         amount,
         has_grace_period,
         grace_period_days,
         grace_period_strategy,
         start_date,
         end_date,
         state
       ) do
    # First check if it's a product
    case Engine.get_product(state, source_name) do
      nil ->
        # Not a product, check if it's a project
        case Engine.get_project(state, source_name) do
          nil ->
            raise "Project or product '#{source_name}' not found"

          built_project ->
            create_from_built_project(
              built_project,
              title,
              type,
              reg_open,
              slug,
              open_and_free,
              requires_enrollment,
              requires_payment,
              payment_options,
              pay_by_institution,
              amount,
              has_grace_period,
              grace_period_days,
              grace_period_strategy,
              start_date,
              end_date,
              state
            )
        end

      product ->
        # Create section from product/blueprint
        create_from_product(
          product,
          title,
          type,
          reg_open,
          slug,
          open_and_free,
          requires_enrollment,
          requires_payment,
          payment_options,
          pay_by_institution,
          amount,
          has_grace_period,
          grace_period_days,
          grace_period_strategy,
          start_date,
          end_date,
          state
        )
    end
  end

  defp create_from_built_project(
         built_project,
         title,
         type,
         reg_open,
         slug,
         open_and_free,
         requires_enrollment,
         requires_payment,
         payment_options,
         pay_by_institution,
         amount,
         has_grace_period,
         grace_period_days,
         grace_period_strategy,
         start_date,
         end_date,
         state
       ) do
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
    attrs =
      %{
        title: title,
        registration_open: reg_open,
        open_and_free: open_and_free,
        requires_enrollment: requires_enrollment,
        requires_payment: requires_payment,
        payment_options: payment_options,
        pay_by_institution: pay_by_institution,
        amount: build_money(amount),
        has_grace_period: requires_payment_value(requires_payment, has_grace_period),
        grace_period_days:
          maybe_include_grace_period_days(requires_payment, has_grace_period, grace_period_days),
        grace_period_strategy: grace_period_strategy,
        start_date: start_date,
        end_date: end_date,
        context_id: "context_#{System.unique_integer([:positive])}",
        institution_id: state.current_institution.id,
        base_project_id: built_project.project.id,
        type: type || :enrollable
      }
      |> reject_nil_values()
      |> maybe_put_slug(slug)

    {:ok, section} = Sections.create_section(attrs)

    # Create section resources from publication
    {:ok, section} = Sections.create_section_resources(section, publication)

    section
  end

  defp create_from_product(
         product,
         title,
         type,
         reg_open,
         slug,
         open_and_free,
         requires_enrollment,
         requires_payment,
         payment_options,
         pay_by_institution,
         amount,
         has_grace_period,
         grace_period_days,
         grace_period_strategy,
         start_date,
         end_date,
         state
       ) do
    # Create section from blueprint/product using the proper Delivery function
    section_params =
      %{
        title: title,
        registration_open: reg_open,
        open_and_free: open_and_free,
        requires_enrollment: requires_enrollment,
        requires_payment: requires_payment,
        payment_options: payment_options,
        pay_by_institution: pay_by_institution,
        amount: build_money(amount),
        has_grace_period: requires_payment_value(requires_payment, has_grace_period),
        grace_period_days:
          maybe_include_grace_period_days(requires_payment, has_grace_period, grace_period_days),
        grace_period_strategy: grace_period_strategy,
        start_date: start_date,
        end_date: end_date,
        context_id: "context_#{System.unique_integer([:positive])}",
        institution_id: state.current_institution.id,
        blueprint_id: product.id,
        type: type || :enrollable
      }
      |> reject_nil_values()
      |> maybe_put_slug(slug)

    {:ok, section} = Delivery.create_from_product(state.current_author, product, section_params)

    section |> Oli.Repo.preload([:blueprint])
  end

  defp create_standalone(
         title,
         type,
         reg_open,
         slug,
         open_and_free,
         requires_enrollment,
         requires_payment,
         payment_options,
         pay_by_institution,
         amount,
         has_grace_period,
         grace_period_days,
         grace_period_strategy,
         start_date,
         end_date,
         state
       ) do
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
    section_attrs =
      %{
        title: title,
        registration_open: reg_open,
        open_and_free: open_and_free,
        requires_enrollment: requires_enrollment,
        requires_payment: requires_payment,
        payment_options: payment_options,
        pay_by_institution: pay_by_institution,
        amount: build_money(amount),
        has_grace_period: requires_payment_value(requires_payment, has_grace_period),
        grace_period_days:
          maybe_include_grace_period_days(requires_payment, has_grace_period, grace_period_days),
        grace_period_strategy: grace_period_strategy,
        start_date: start_date,
        end_date: end_date,
        context_id: "context_#{System.unique_integer([:positive])}",
        institution_id: state.current_institution.id,
        base_project_id: project.id,
        type: type || :enrollable
      }
      |> reject_nil_values()
      |> maybe_put_slug(slug)

    {:ok, section} = Sections.create_section(section_attrs)

    # Create section resources
    {:ok, section} = Sections.create_section_resources(section, publication)

    section
  end

  defp maybe_put_slug(attrs, nil), do: attrs
  defp maybe_put_slug(attrs, slug), do: Map.put(attrs, :slug, slug)

  defp reject_nil_values(attrs) do
    Map.reject(attrs, fn {_key, value} -> is_nil(value) end)
  end

  defp build_money(nil), do: nil

  defp build_money(%{"amount" => amount, "currency" => currency}) do
    Money.new(amount, currency)
  end

  defp requires_payment_value(nil, nil), do: nil
  defp requires_payment_value(nil, value), do: value
  defp requires_payment_value(false, _value), do: false
  defp requires_payment_value(true, nil), do: true
  defp requires_payment_value(true, value), do: value

  defp maybe_include_grace_period_days(requires_payment, has_grace_period, grace_period_days) do
    if requires_payment != false and has_grace_period != false do
      grace_period_days
    else
      nil
    end
  end
end
