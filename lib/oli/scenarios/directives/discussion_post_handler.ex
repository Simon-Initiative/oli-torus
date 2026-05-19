defmodule Oli.Scenarios.Directives.DiscussionPostHandler do
  @moduledoc """
  Creates a discussion post for a scenario student and updates certificate state deterministically.
  """

  alias Oli.CertificationEligibility
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Resources.Collaboration.PostContent
  alias Oli.Scenarios.DirectiveTypes.{DiscussionPostDirective, ExecutionState}
  alias Oli.Scenarios.Engine

  def handle(
        %DiscussionPostDirective{student: student_name, section: section_name, body: body},
        %ExecutionState{} = state
      ) do
    with {:ok, student} <- fetch_user(state, student_name),
         {:ok, section} <- fetch_section(state, section_name),
         {:ok, _post} <-
           CertificationEligibility.create_post_and_verify_qualification(
             %{
               user_id: student.id,
               section_id: section.id,
               visibility: :public,
               content: %PostContent{message: body}
             },
             true
           ) do
      GrantedCertificates.has_qualified(student.id, section.id)
      {:ok, state}
    else
      {:error, reason} ->
        {:error, "Failed to create discussion post: #{inspect(reason)}"}
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
