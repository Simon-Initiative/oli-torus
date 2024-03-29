defmodule Oli.PartComponentsTest do
  use Oli.DataCase
  alias Oli.PartComponents
  import ExUnit.Assertions

  setup do
    part_component_registration_fixture()
    author_project_fixture()
  end

  describe "add part component to project" do
    test "adding a custom part component to a project", %{project: project} do
      custom_part = PartComponents.get_registration_by_slug("test_part_component")

      PartComponents.enable_part_component_in_project(project.slug, custom_part.slug)
      project_parts = PartComponents.part_components_for_project(project)

      assert Enum.member?(project_parts, %{
               enabled: true,
               global: false,
               authoring_script: "test_part_component_authoring.js",
               authoring_element: "test-part-component-authoring",
               delivery_script: "test_part_component_delivery.js",
               delivery_element: "test-part-component-delivery",
               description: "test part component for testing",
               title: "Test Part Component",
               icon: "nothing",
               author: "Test McTesterson",
               slug: "test_part_component"
             })
    end

    test "removing a custom registered part component from a project", %{project: project} do
      custom_part = PartComponents.get_registration_by_slug("test_part_component")

      PartComponents.enable_part_component_in_project(project.slug, custom_part.slug)
      PartComponents.disable_part_component_in_project(project.slug, custom_part.slug)
      project_parts = PartComponents.part_components_for_project(project)

      assert Enum.member?(project_parts, %{
               enabled: false,
               global: false,
               authoring_script: "test_part_component_authoring.js",
               authoring_element: "test-part-component-authoring",
               delivery_script: "test_part_component_delivery.js",
               delivery_element: "test-part-component-delivery",
               description: "test part component for testing",
               title: "Test Part Component",
               icon: "nothing",
               author: "Test McTesterson",
               slug: "test_part_component"
             })
    end
  end
end
