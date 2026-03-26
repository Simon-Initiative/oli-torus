defmodule Oli.Scenarios.Directives.CertificateHandler do
  @moduledoc """
  Configures certificate settings on a scenario section or product target.
  """

  alias Oli.Delivery.Certificates
  alias Oli.Delivery.Sections
  alias Oli.Scenarios.DirectiveTypes.{CertificateDirective, ExecutionState}
  alias Oli.Scenarios.Directives.CertificateSupport
  alias Oli.Scenarios.Engine

  def handle(
        %CertificateDirective{target: target_name, enabled: enabled} = directive,
        %ExecutionState{} = state
      ) do
    with {:ok, target_type, target} <- CertificateSupport.resolve_target(state, target_name),
         {:ok, updated_target} <- Sections.update_section(target, %{certificate_enabled: enabled}),
         {:ok, _certificate} <- maybe_upsert_certificate(updated_target, directive) do
      updated_state =
        case target_type do
          :section -> Engine.put_section(state, target_name, updated_target)
          :product -> Engine.put_product(state, target_name, updated_target)
        end

      {:ok, updated_state}
    else
      {:error, reason} ->
        {:error, "Failed to configure certificate for '#{target_name}': #{inspect(reason)}"}
    end
  end

  defp maybe_upsert_certificate(_section, %CertificateDirective{enabled: false}),
    do: {:ok, :disabled}

  defp maybe_upsert_certificate(section, %CertificateDirective{} = directive) do
    attrs =
      section
      |> build_certificate_attrs(directive)
      |> Map.put(:section_id, section.id)

    case Certificates.get_certificate_by(%{section_id: section.id}) do
      nil ->
        Certificates.create(attrs)

      certificate ->
        Certificates.update_certificate(certificate, attrs)
    end
  end

  defp build_certificate_attrs(section, %CertificateDirective{
         thresholds: thresholds,
         design: design
       }) do
    thresholds = thresholds || %{}
    design = design || %{}
    scored_page_ids = resolve_scored_pages(section, Map.get(thresholds, :scored_pages))

    %{
      required_discussion_posts: Map.get(thresholds, :required_discussion_posts, 0),
      required_class_notes: Map.get(thresholds, :required_class_notes, 0),
      min_percentage_for_completion: Map.get(thresholds, :min_percentage_for_completion, 75.0),
      min_percentage_for_distinction: Map.get(thresholds, :min_percentage_for_distinction, 95.0),
      assessments_apply_to: parse_assessments_apply_to(thresholds),
      custom_assessments: scored_page_ids,
      requires_instructor_approval: Map.get(thresholds, :requires_instructor_approval, false),
      title: Map.get(design, :title, "Certificate of Completion"),
      description: Map.get(design, :description, "Course completion certificate"),
      admin_name1: Map.get(design, :admin_name1),
      admin_title1: Map.get(design, :admin_title1),
      admin_name2: Map.get(design, :admin_name2),
      admin_title2: Map.get(design, :admin_title2),
      admin_name3: Map.get(design, :admin_name3),
      admin_title3: Map.get(design, :admin_title3)
    }
  end

  defp resolve_scored_pages(_section, nil), do: []

  defp resolve_scored_pages(section, page_titles) when is_list(page_titles) do
    Enum.map(page_titles, fn title ->
      case CertificateSupport.find_resource_id_by_title(section, title) do
        {:ok, resource_id} -> resource_id
        {:error, reason} -> raise reason
      end
    end)
  end

  defp parse_assessments_apply_to(%{assessments_apply_to: value})
       when value in ["all", "custom", :all, :custom],
       do: value

  defp parse_assessments_apply_to(%{scored_pages: [_ | _]}), do: :custom
  defp parse_assessments_apply_to(_), do: :all
end
