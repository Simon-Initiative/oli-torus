defmodule Oli.Scenarios.Directives.Assert.AnnotationAssertion do
  @moduledoc """
  Verifies named annotations, replies, and reactions.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.UserReactionPost
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers
  alias Oli.Scenarios.Directives.CertificateSupport
  alias Oli.Scenarios.Engine

  def assert(%AssertDirective{annotation: annotation}, state) when is_map(annotation) do
    with {:ok, post} <- fetch_post(state, annotation.post),
         {:ok, section_id} <- expected_section_id(state, annotation.section),
         {:ok, page_resource_id} <- expected_page_resource_id(state, annotation),
         {:ok, author_id} <- expected_user_id(state, annotation.author),
         {:ok, parent_post_id} <- expected_parent_post_id(state, annotation.reply_to),
         {:ok, reacted_by_user_id} <- expected_user_id(state, annotation.reacted_by) do
      verification =
        verify(
          post,
          annotation,
          section_id,
          page_resource_id,
          author_id,
          parent_post_id,
          reacted_by_user_id
        )

      {:ok, state, verification}
    else
      {:error, reason} -> {:error, "Failed to assert annotation: #{reason}"}
    end
  end

  def assert(%AssertDirective{annotation: nil}, state), do: {:ok, state, nil}

  defp fetch_post(state, name) do
    case Engine.get_annotation_post(state, name) do
      nil ->
        {:error, "Collaboration post '#{name}' not found"}

      post ->
        {:ok, Collaboration.get_post_by(%{id: post.id}) || post}
    end
  end

  defp expected_section_id(_state, nil), do: {:ok, nil}

  defp expected_section_id(state, section_name) do
    case Helpers.get_section(state, section_name) do
      {:ok, section} -> {:ok, section.id}
      error -> error
    end
  end

  defp expected_page_resource_id(_state, %{page: nil}), do: {:ok, nil}

  defp expected_page_resource_id(_state, %{section: nil, page: _page}) do
    {:error, "section is required when asserting an annotation page"}
  end

  defp expected_page_resource_id(state, %{section: section_name, page: page}) do
    with {:ok, section} <- Helpers.get_section(state, section_name),
         {:ok, resource_id} <- CertificateSupport.find_resource_id_by_title(section, page) do
      {:ok, resource_id}
    end
  end

  defp expected_user_id(_state, nil), do: {:ok, nil}

  defp expected_user_id(state, user_name) do
    case Helpers.get_user(state, user_name) do
      {:ok, user} -> {:ok, user.id}
      error -> error
    end
  end

  defp expected_parent_post_id(_state, nil), do: {:ok, nil}

  defp expected_parent_post_id(state, parent_name) do
    case Engine.get_annotation_post(state, parent_name) do
      nil -> {:error, "Parent collaboration post '#{parent_name}' not found"}
      post -> {:ok, post.id}
    end
  end

  defp verify(
         post,
         annotation,
         section_id,
         page_resource_id,
         author_id,
         parent_post_id,
         reacted_by_user_id
       ) do
    reaction = annotation.reaction || :like

    failures =
      [
        compare(post.section_id, section_id, "section"),
        compare(post.resource_id, page_resource_id, "page resource"),
        compare(post.annotated_resource_id, page_resource_id, "annotated resource"),
        compare(post.content.message, annotation.body, "body"),
        compare(post.user_id, author_id, "author"),
        compare(post.status, annotation.status, "status"),
        compare(post.visibility, annotation.visibility, "visibility"),
        compare(post.annotation_type, annotation.annotation_type, "annotation_type"),
        compare(post.annotated_block_id, annotation.block_id, "block_id"),
        compare(post.parent_post_id, parent_post_id, "reply_to"),
        compare(
          reaction_count(post.id, reaction, annotation.reaction_count),
          annotation.reaction_count,
          "reaction_count"
        ),
        compare(
          reacted?(post.id, reacted_by_user_id, reaction),
          expected_reacted(annotation.reacted_by),
          "reacted_by"
        )
      ]
      |> Enum.reject(&(&1 == :ok))

    case failures do
      [] ->
        %VerificationResult{
          to: annotation.post,
          passed: true,
          message: "Annotation assertion passed for '#{annotation.post}'"
        }

      failures ->
        %VerificationResult{
          to: annotation.post,
          passed: false,
          message: Enum.join(failures, "; ")
        }
    end
  end

  defp compare(_actual, nil, _label), do: :ok

  defp compare(actual, expected, label) do
    case actual == expected do
      true -> :ok
      false -> "expected #{label}=#{inspect(expected)}, got #{inspect(actual)}"
    end
  end

  defp reaction_count(_post_id, _reaction, nil), do: nil

  defp reaction_count(post_id, reaction, _expected_count) do
    UserReactionPost
    |> where([r], r.post_id == ^post_id and r.reaction == ^reaction)
    |> Repo.aggregate(:count)
  end

  defp expected_reacted(nil), do: nil
  defp expected_reacted(_user_name), do: true

  defp reacted?(_post_id, nil, _reaction), do: nil

  defp reacted?(post_id, user_id, reaction) do
    not is_nil(Collaboration.get_reaction(post_id, user_id, reaction))
  end
end
