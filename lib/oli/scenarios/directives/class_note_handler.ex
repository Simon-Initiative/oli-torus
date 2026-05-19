defmodule Oli.Scenarios.Directives.ClassNoteHandler do
  @moduledoc """
  Creates a public class note for a scenario student and updates certificate state deterministically.
  """

  alias Oli.CertificationEligibility
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Resources.Collaboration.PostContent
  alias Oli.Scenarios.DirectiveTypes.{ClassNoteDirective, ExecutionState}
  alias Oli.Scenarios.Directives.CertificateSupport
  alias Oli.Scenarios.Engine

  def handle(
        %ClassNoteDirective{student: student_name, section: section_name, page: page, body: body},
        %ExecutionState{} = state
      ) do
    with {:ok, student} <- fetch_user(state, student_name),
         {:ok, section} <- fetch_section(state, section_name),
         {:ok, annotated_resource_id} <-
           CertificateSupport.find_resource_id_by_title(section, page),
         {:ok, _post} <-
           CertificationEligibility.create_post_and_verify_qualification(
             %{
               user_id: student.id,
               section_id: section.id,
               resource_id: annotated_resource_id,
               annotated_resource_id: annotated_resource_id,
               visibility: :public,
               content: %PostContent{message: body}
             },
             true
           ) do
      GrantedCertificates.has_qualified(student.id, section.id)
      {:ok, state}
    else
      {:error, reason} ->
        {:error, "Failed to create class note: #{inspect(reason)}"}
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
