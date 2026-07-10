defmodule Oli.Scenarios.Directives.DiscussionPostHandler do
  @moduledoc """
  Creates a discussion post for a scenario student and updates certificate state deterministically.
  """

  alias Oli.CertificationEligibility
  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.PostContent
  alias Oli.Scenarios.DirectiveTypes.{DiscussionPostDirective, ExecutionState}
  alias Oli.Scenarios.Engine
  alias Lti_1p3.Roles.ContextRoles

  def handle(
        %DiscussionPostDirective{
          name: post_name,
          student: student_name,
          section: section_name,
          body: body,
          reply_to: reply_to,
          anonymous: anonymous
        },
        %ExecutionState{} = state
      ) do
    with {:ok, student} <- fetch_user(state, student_name),
         {:ok, section} <- fetch_section(state, section_name),
         :ok <- validate_student_enrollment(student, section),
         {:ok, root_section_resource} <- fetch_root_section_resource(section),
         {:ok, parent_post} <- fetch_parent_post(state, reply_to),
         :ok <- validate_parent_post(parent_post, section, root_section_resource),
         {:ok, attrs} <-
           post_attrs(student, section, root_section_resource, parent_post, body, anonymous),
         {:ok, post} <-
           CertificationEligibility.create_post_and_verify_qualification(
             attrs,
             true
           ) do
      GrantedCertificates.has_qualified(student.id, section.id)
      {:ok, maybe_store_post(state, post_name, post)}
    else
      {:error, reason} ->
        {:error, "Failed to create discussion post: #{inspect(reason)}"}
    end
  end

  defp post_attrs(student, section, root_section_resource, parent_post, body, anonymous) do
    config = root_section_resource.collab_space_config

    cond do
      !discussions_enabled?(section, config) ->
        {:error, "Discussions are not enabled for section '#{section.slug}'"}

      anonymous && !anonymous_posting_enabled?(config) ->
        {:error, "Anonymous posting is not enabled for section '#{section.slug}'"}

      true ->
        auto_accept = auto_accept_enabled?(config)

        attrs =
          %{
            user_id: student.id,
            section_id: section.id,
            resource_id: root_section_resource.resource_id,
            status: if(auto_accept, do: :approved, else: :submitted),
            visibility: :public,
            anonymous: anonymous,
            content: %PostContent{message: body}
          }
          |> maybe_put_parent(parent_post)

        {:ok, attrs}
    end
  end

  defp discussions_enabled?(section, config) do
    (section.contains_discussions == true and config) && Map.get(config, :status) == :enabled
  end

  defp auto_accept_enabled?(nil), do: true
  defp auto_accept_enabled?(config), do: Map.get(config, :auto_accept) != false

  defp anonymous_posting_enabled?(nil), do: false
  defp anonymous_posting_enabled?(config), do: Map.get(config, :anonymous_posting, false)

  defp validate_student_enrollment(student, section) do
    learner_role_id = ContextRoles.get_role(:context_learner).id

    case Sections.get_enrollment(section.slug, student.id) do
      nil ->
        {:error, "Student '#{student.email}' is not enrolled in section '#{section.slug}'"}

      enrollment ->
        enrollment = Repo.preload(enrollment, :context_roles)

        if Enum.any?(enrollment.context_roles, &(&1.id == learner_role_id)) do
          :ok
        else
          {:error, "Student '#{student.email}' is not enrolled in section '#{section.slug}'"}
        end
    end
  end

  defp validate_parent_post(nil, _section, _root_section_resource), do: :ok

  defp validate_parent_post(parent_post, section, root_section_resource) do
    if parent_post.section_id == section.id and
         parent_post.resource_id == root_section_resource.resource_id do
      :ok
    else
      {:error, "Parent discussion post does not belong to section '#{section.slug}'"}
    end
  end

  defp maybe_put_parent(attrs, nil), do: attrs

  defp maybe_put_parent(attrs, parent_post) do
    attrs
    |> Map.put(:parent_post_id, parent_post.id)
    |> Map.put(:thread_root_id, parent_post.thread_root_id || parent_post.id)
  end

  defp maybe_store_post(state, nil, _post), do: state
  defp maybe_store_post(state, name, post), do: Engine.put_discussion_post(state, name, post)

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

  defp fetch_root_section_resource(section) do
    section = Repo.preload(section, :root_section_resource)

    case section.root_section_resource do
      nil -> {:error, "Root section resource not found for section '#{section.slug}'"}
      root_section_resource -> {:ok, root_section_resource}
    end
  end

  defp fetch_parent_post(_state, nil), do: {:ok, nil}

  defp fetch_parent_post(state, name) do
    case Engine.get_discussion_post(state, name) do
      nil ->
        {:error, "Discussion post '#{name}' not found"}

      post ->
        {:ok, Collaboration.get_post_by(%{id: post.id}) || post}
    end
  end
end
