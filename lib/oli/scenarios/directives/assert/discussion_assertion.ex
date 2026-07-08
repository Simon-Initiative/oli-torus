defmodule Oli.Scenarios.Directives.Assert.DiscussionAssertion do
  @moduledoc """
  Handles assertions for course discussion configuration and named posts.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers
  alias Oli.Scenarios.Engine

  def assert(%AssertDirective{discussion: discussion_data}, state)
      when is_map(discussion_data) do
    with {:ok, section} <- Helpers.get_section(state, discussion_data.section),
         {:ok, student} <- maybe_get_student(state, discussion_data.student),
         {:ok, post} <- maybe_get_post(state, discussion_data.post),
         verification_result <- verify(section, student, post, discussion_data) do
      {:ok, state, verification_result}
    else
      {:error, reason} ->
        {:error, "Failed to assert discussion: #{reason}"}
    end
  end

  def assert(%AssertDirective{discussion: nil}, state), do: {:ok, state, nil}

  defp maybe_get_student(_state, nil), do: {:ok, nil}
  defp maybe_get_student(state, student_name), do: Helpers.get_user(state, student_name)

  defp maybe_get_post(_state, nil), do: {:ok, nil}

  defp maybe_get_post(state, post_name) do
    case Engine.get_discussion_post(state, post_name) do
      nil -> {:error, "Discussion post '#{post_name}' not found"}
      post -> {:ok, Collaboration.get_post_by(%{id: post.id}) || post}
    end
  end

  defp verify(section, student, post, discussion_data) do
    section = Repo.preload(section, :root_section_resource)
    config = section.root_section_resource && section.root_section_resource.collab_space_config

    checks =
      [
        compare_field(
          section.contains_discussions,
          discussion_data.contains_discussions,
          "contains_discussions"
        ),
        compare_field(config && config.auto_accept, discussion_data.auto_accept, "auto_accept"),
        compare_field(
          config && config.anonymous_posting,
          discussion_data.anonymous_posting,
          "anonymous_posting"
        ),
        compare_field(post && post.status, discussion_data.status, "status"),
        check_visibility(section, student, post, discussion_data.visible)
      ]
      |> Enum.reject(&(&1 == :ok))

    case checks do
      [] ->
        %VerificationResult{
          to: discussion_data.section,
          passed: true,
          message: "Discussion assertion passed for '#{discussion_data.section}'"
        }

      failures ->
        %VerificationResult{
          to: discussion_data.section,
          passed: false,
          message: Enum.join(failures, "; ")
        }
    end
  end

  defp compare_field(_actual, nil, _label), do: :ok

  defp compare_field(actual, expected, label) do
    if actual == expected,
      do: :ok,
      else: "expected #{label}=#{inspect(expected)}, got #{inspect(actual)}"
  end

  defp check_visibility(_section, _student, _post, nil), do: :ok

  defp check_visibility(_section, nil, _post, _expected) do
    "student is required when asserting discussion visibility"
  end

  defp check_visibility(_section, _student, nil, _expected) do
    "post is required when asserting discussion visibility"
  end

  defp check_visibility(section, student, post, expected) do
    visible? =
      section.root_section_resource.resource_id
      |> visible_post?(section, student, post)

    if visible? == expected,
      do: :ok,
      else: "expected visible=#{inspect(expected)}, got #{inspect(visible?)}"
  end

  defp visible_post?(root_resource_id, section, student, post) do
    Repo.exists?(
      from p in Post,
        where:
          p.id == ^post.id and
            p.section_id == ^section.id and
            p.resource_id == ^root_resource_id and
            p.visibility == :public and
            (p.status in [:approved, :archived, :deleted] or
               (p.status == :submitted and p.user_id == ^student.id))
    )
  end
end
