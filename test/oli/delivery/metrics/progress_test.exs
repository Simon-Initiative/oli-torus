defmodule Oli.Delivery.Metrics.ProgressTest do
  use Oli.DataCase

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core

  defp set_progress(section_id, resource_id, user_id, progress) do
    Core.track_access(resource_id, section_id, user_id)
    |> Core.update_resource_access(%{progress: progress})
  end

  describe "progress calculations" do
    setup do
      map = Seeder.base_project_with_larger_hierarchy()
      map = Seeder.add_user(map, %{}, :this_user)
      Seeder.add_users_to_section(map, :section, [:this_user])

      {:ok, _} = Sections.rebuild_contained_pages(map.section)

      user_id = map.this_user.id
      section = map.section

      [p1, p2, p3] = map.mod1_pages
      [p4, p5, p6] = map.mod2_pages
      [p7, p8, _, _] = map.mod3_pages

      set_progress(section.id, p1.published_resource.resource_id, user_id, 0.5)
      set_progress(section.id, p2.published_resource.resource_id, user_id, 1)
      set_progress(section.id, p3.published_resource.resource_id, user_id, 0.0)
      set_progress(section.id, p4.published_resource.resource_id, user_id, 0.1)
      set_progress(section.id, p5.published_resource.resource_id, user_id, 0.2)
      set_progress(section.id, p6.published_resource.resource_id, user_id, 0.3)
      set_progress(section.id, p7.published_resource.resource_id, user_id, 0.5)
      set_progress(section.id, p8.published_resource.resource_id, user_id, 0.5)

      map
    end

    test "progress calculates correctly", %{
      section: section,
      this_user: this_user,
      mod1_resource: mod1_resource,
      mod2_resource: mod2_resource,
      mod3_resource: mod3_resource,
      unit1_resource: unit1_resource,
      unit2_resource: unit2_resource
    } do

      # Verify the modules
      assert_in_delta 0.5, Metrics.progress_for(section.id, mod1_resource.id, this_user.id), 0.0001
      assert_in_delta 0.2, Metrics.progress_for(section.id, mod2_resource.id, this_user.id), 0.0001
      assert_in_delta 0.25, Metrics.progress_for(section.id, mod3_resource.id, this_user.id), 0.0001

      # Then the units
      assert_in_delta 0.35, Metrics.progress_for(section.id, unit1_resource.id, this_user.id), 0.0001
      assert_in_delta 0.25, Metrics.progress_for(section.id, unit2_resource.id, this_user.id), 0.0001

      # Then the entire course (there are two other pages, outside of the units)
      assert_in_delta 0.2583, Metrics.progress_for(section.id, nil, this_user.id), 0.0001

    end

  end
end
