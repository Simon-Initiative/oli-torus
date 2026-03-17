defmodule Oli.Dashboard.ScopeResolverTest do
  use Oli.DataCase

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Dashboard.ScopeResolver
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  setup :create_section_with_container

  describe "resolve/2" do
    test "allows instructor to resolve default course scope", %{
      section: section,
      instructor: instructor
    } do
      assert {:ok, %{container_type: :course, container_id: nil}} =
               ScopeResolver.resolve(%{}, %{
                 dashboard_context_type: :section,
                 dashboard_context_id: section.id,
                 user: instructor
               })
    end

    test "allows instructor to resolve a known container scope", %{
      section: section,
      instructor: instructor,
      container_resource_id: container_resource_id
    } do
      assert {:ok, %{container_type: :container, container_id: ^container_resource_id}} =
               ScopeResolver.resolve(
                 %{container_type: :container, container_id: container_resource_id},
                 %{
                   dashboard_context_type: :section,
                   dashboard_context_id: section.id,
                   user: instructor
                 }
               )
    end

    test "rejects unknown containers deterministically", %{
      section: section,
      instructor: instructor
    } do
      assert {:error, {:invalid_scope, {:unknown_container, 999_999}}} =
               ScopeResolver.resolve(
                 %{container_type: :container, container_id: 999_999},
                 %{
                   dashboard_context_type: :section,
                   dashboard_context_id: section.id,
                   user: instructor
                 }
               )
    end

    test "rejects unauthorized users before scope resolution", %{
      section: section,
      learner: learner
    } do
      assert {:error, {:unauthorized_scope, :section_access_denied}} =
               ScopeResolver.resolve(%{}, %{
                 dashboard_context_type: :section,
                 dashboard_context_id: section.id,
                 user: learner
               })
    end
  end

  describe "validate_container/2" do
    test "returns invalid scope context when section does not exist", %{instructor: instructor} do
      assert {:error, {:invalid_scope_context, {:unknown_section, 999_999}}} =
               ScopeResolver.resolve(%{}, %{
                 dashboard_context_type: :section,
                 dashboard_context_id: 999_999,
                 user: instructor
               })
    end
  end

  defp create_section_with_container(_) do
    author = insert(:user)
    project = insert(:project, authors: [author.author])

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page 1"
      )

    module_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Module 1",
        children: [page_revision.resource_id]
      )

    root_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root Container",
        children: [module_revision.resource_id]
      )

    all_revisions = [root_revision, module_revision, page_revision]

    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{project_id: project.id, resource_id: revision.resource_id})
    end)

    publication =
      insert(:publication, %{project: project, root_resource_id: root_revision.resource_id})

    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author.author
      })
    end)

    section = insert(:section, base_project: project)
    {:ok, _section} = Sections.create_section_resources(section, publication)

    instructor = insert(:user)
    learner = insert(:user)

    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
    Sections.enroll(learner.id, section.id, [ContextRoles.get_role(:context_learner)])

    %{
      section: section,
      instructor: instructor,
      learner: learner,
      container_resource_id: module_revision.resource_id
    }
  end
end
