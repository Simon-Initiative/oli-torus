defmodule Oli.Delivery.Metrics.CompletedTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core

  defp set_progress(section_id, resource_id, user_id, progress, revision) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: :evaluated
    })
  end

  describe "completed calculations" do
    setup do
      # Root Container
      #  - Page A
      #  - Page B
      #  - Unit 1
      #    - Module 1
      #      - Page 1
      #      - Page 2
      #      - Page 3
      #    - Module 2
      #      - Page 4
      #      - Page 5
      #      - Page 6
      #  - Unit 2
      #    - Module 3
      #      - Page 7
      #      - Page 8
      #      - Page 9
      #      - Page 10

      map = Seeder.base_project_with_larger_hierarchy()
      map = Seeder.add_user(map, %{}, :this_user)
      Seeder.add_users_to_section(map, :section, [:this_user])

      {:ok, _} = Sections.rebuild_contained_pages(map.section)

      user_id = map.this_user.id
      section = map.section

      [p1, p2, p3] = map.mod1_pages
      [p4, p5, p6] = map.mod2_pages
      [p7, p8, _, _] = map.mod3_pages

      # Note: only pages with progress == 1.0 will be counted as completed
      set_progress(section.id, p1.published_resource.resource_id, user_id, 0.5, p1.revision)
      set_progress(section.id, p2.published_resource.resource_id, user_id, 1.0, p2.revision)
      set_progress(section.id, p3.published_resource.resource_id, user_id, 1.0, p3.revision)
      set_progress(section.id, p4.published_resource.resource_id, user_id, 0.1, p4.revision)
      set_progress(section.id, p5.published_resource.resource_id, user_id, 0.5, p5.revision)
      set_progress(section.id, p6.published_resource.resource_id, user_id, 1.0, p6.revision)
      set_progress(section.id, p7.published_resource.resource_id, user_id, 1.0, p7.revision)
      set_progress(section.id, p8.published_resource.resource_id, user_id, 1.0, p8.revision)

      map
    end

    test "container based progress calculates correctly", %{
      section: section,
      this_user: this_user,
      mod1_resource: mod1_resource,
      mod2_resource: mod2_resource,
      mod3_resource: mod3_resource,
      unit1_resource: unit1_resource,
      unit2_resource: unit2_resource
    } do
      # Verify the modules
      result = Metrics.raw_completed_pages_for(section.id, this_user.id, mod1_resource.id)
      assert result[this_user.id] == 2
      assert result.total_pages == 3

      result = Metrics.raw_completed_pages_for(section.id, this_user.id, mod2_resource.id)

      assert result[this_user.id] == 1
      assert result.total_pages == 3

      result = Metrics.raw_completed_pages_for(section.id, this_user.id, mod3_resource.id)

      assert result[this_user.id] == 2
      assert result.total_pages == 4

      # Then the units
      result = Metrics.raw_completed_pages_for(section.id, this_user.id, unit1_resource.id)
      assert result[this_user.id] == 3
      assert result.total_pages == 6

      result = Metrics.raw_completed_pages_for(section.id, this_user.id, unit2_resource.id)
      assert result[this_user.id] == 2
      assert result.total_pages == 4

      # Then the entire course (there are two other pages, outside of the units)
      result = Metrics.raw_completed_pages_for(section.id, this_user.id)
      assert result[this_user.id] == 5
      assert result.total_pages == 12
    end
  end
end
