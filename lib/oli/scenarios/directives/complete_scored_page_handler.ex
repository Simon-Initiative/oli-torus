defmodule Oli.Scenarios.Directives.CompleteScoredPageHandler do
  @moduledoc """
  Records a scored-page completion for certificate qualification workflows.
  """

  alias Oli.CertificationEligibility
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Scenarios.DirectiveTypes.{CompleteScoredPageDirective, ExecutionState}
  alias Oli.Scenarios.Directives.CertificateSupport
  alias Oli.Scenarios.Engine

  def handle(
        %CompleteScoredPageDirective{
          student: student_name,
          section: section_name,
          page: page,
          score: score,
          out_of: out_of
        },
        %ExecutionState{} = state
      ) do
    with {:ok, student} <- fetch_user(state, student_name),
         {:ok, section} <- fetch_section(state, section_name),
         {:ok, resource_id} <- CertificateSupport.find_resource_id_by_title(section, page) do
      resource_access = Core.track_access(resource_id, section.id, student.id)

      case CertificationEligibility.update_resource_access_and_verify_qualification(
             resource_access,
             %{score: score, out_of: out_of}
           ) do
        {:ok, _resource_access} ->
          GrantedCertificates.has_qualified(student.id, section.id)
          {:ok, state}

        {:error, reason} ->
          {:error, "Failed to complete scored page: #{inspect(reason)}"}
      end
    else
      {:error, reason} ->
        {:error, "Failed to complete scored page: #{inspect(reason)}"}
    end
  end

  defp fetch_user(state, name) do
    case Engine.get_user(state, name) do
      nil -> {:error, "User '#{name}' not found"}
      user -> {:ok, user}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end
end
