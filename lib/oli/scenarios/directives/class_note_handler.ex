defmodule Oli.Scenarios.Directives.ClassNoteHandler do
  @moduledoc """
  Creates a public class note for a scenario student and updates certificate state deterministically.
  """

  alias Oli.CertificationEligibility
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.PostContent
  alias Oli.Scenarios.DirectiveTypes.{ClassNoteDirective, ExecutionState}
  alias Oli.Scenarios.Directives.CertificateSupport
  alias Oli.Scenarios.Engine

  def handle(
        %ClassNoteDirective{
          name: name,
          student: student_name,
          section: section_name,
          page: page,
          body: body,
          reply_to: reply_to,
          block_id: block_id
        },
        %ExecutionState{} = state
      ) do
    with {:ok, student} <- fetch_user(state, student_name),
         {:ok, section} <- fetch_section(state, section_name),
         {:ok, annotated_resource_id} <-
           CertificateSupport.find_resource_id_by_title(section, page),
         {:ok, parent_post} <- fetch_parent_post(state, reply_to),
         :ok <- validate_parent_post(parent_post, section.id, annotated_resource_id),
         {:ok, annotation_block_id} <- resolve_block_id(parent_post, block_id),
         {:ok, post} <-
           CertificationEligibility.create_post_and_verify_qualification(
             post_attrs(
               student.id,
               section.id,
               annotated_resource_id,
               annotation_block_id,
               parent_post,
               body
             ),
             true
           ) do
      GrantedCertificates.has_qualified(student.id, section.id)
      {:ok, maybe_store_post(state, name, post)}
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

  defp fetch_parent_post(_state, nil), do: {:ok, nil}

  defp fetch_parent_post(state, name) do
    case Engine.get_annotation_post(state, name) do
      nil ->
        {:error, "Collaboration post '#{name}' not found"}

      post ->
        {:ok, Collaboration.get_post_by(%{id: post.id}) || post}
    end
  end

  defp validate_parent_post(nil, _section_id, _annotated_resource_id), do: :ok

  defp validate_parent_post(parent_post, section_id, annotated_resource_id) do
    case parent_post.section_id == section_id and
           parent_post.resource_id == annotated_resource_id and
           parent_post.annotated_resource_id == annotated_resource_id do
      true -> :ok
      false -> {:error, "Parent note does not belong to the requested section and page"}
    end
  end

  defp resolve_block_id(nil, block_id), do: {:ok, block_id}
  defp resolve_block_id(parent_post, nil), do: {:ok, parent_post.annotated_block_id}

  defp resolve_block_id(parent_post, block_id) do
    case parent_post.annotated_block_id == block_id do
      true -> {:ok, block_id}
      false -> {:error, "Reply block_id must match the parent note"}
    end
  end

  defp post_attrs(user_id, section_id, annotated_resource_id, block_id, parent_post, body) do
    %{
      user_id: user_id,
      section_id: section_id,
      resource_id: annotated_resource_id,
      annotated_resource_id: annotated_resource_id,
      annotated_block_id: block_id,
      annotation_type: annotation_type(block_id),
      visibility: :public,
      content: %PostContent{message: body}
    }
    |> maybe_put_parent(parent_post)
  end

  defp annotation_type(nil), do: :none
  defp annotation_type(_block_id), do: :point

  defp maybe_put_parent(attrs, nil), do: attrs

  defp maybe_put_parent(attrs, parent_post) do
    attrs
    |> Map.put(:parent_post_id, parent_post.id)
    |> Map.put(:thread_root_id, parent_post.thread_root_id || parent_post.id)
  end

  defp maybe_store_post(state, nil, _post), do: state
  defp maybe_store_post(state, name, post), do: Engine.put_annotation_post(state, name, post)
end
