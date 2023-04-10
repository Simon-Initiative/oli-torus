defmodule Oli.Delivery.Metrics.ProgressTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Lti_1p3.Tool.ContextRoles

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

      # Notice that we aren't setting progress - even to 0 - for p9 and p10.
      # It is an important test case to NOT have a resource_access record present for
      # a couple of these pages.  We need to make sure the progress for pages that
      # have never been visited is considered.

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
      assert_in_delta 0.5,
                      Map.get(
                        Metrics.progress_for(section.id, this_user.id, mod1_resource.id),
                        this_user.id
                      ),
                      0.0001

      assert_in_delta 0.2,
                      Map.get(
                        Metrics.progress_for(section.id, this_user.id, mod2_resource.id),
                        this_user.id
                      ),
                      0.0001

      assert_in_delta 0.25,
                      Map.get(
                        Metrics.progress_for(section.id, this_user.id, mod3_resource.id),
                        this_user.id
                      ),
                      0.0001

      # Then the units
      assert_in_delta 0.35,
                      Map.get(
                        Metrics.progress_for(section.id, this_user.id, unit1_resource.id),
                        this_user.id
                      ),
                      0.0001

      assert_in_delta 0.25,
                      Map.get(
                        Metrics.progress_for(section.id, this_user.id, unit2_resource.id),
                        this_user.id
                      ),
                      0.0001

      # Then the entire course (there are two other pages, outside of the units)
      assert_in_delta 0.2583,
                      Map.get(Metrics.progress_for(section.id, this_user.id), this_user.id),
                      0.0001

      assert_in_delta 0.2583,
                      Map.get(Metrics.progress_for(section.id, this_user.id, nil), this_user.id),
                      0.0001
    end

    test "container based progress across collection of containers works correctly",
         %{
           section: section,
           this_user: this_user,
           mod1_resource: mod1_resource,
           mod2_resource: mod2_resource,
           mod3_resource: mod3_resource,
           unit1_resource: unit1_resource,
           unit2_resource: unit2_resource
         } = map do
      [r1, r2, r3] =
        Metrics.progress_across(
          section.id,
          [mod1_resource.id, mod2_resource.id, mod3_resource.id],
          this_user.id
        )
        |> Enum.map(fn {_id, progress} -> progress end)
        |> Enum.sort()

      assert_in_delta 0.2, r1, 0.0001
      assert_in_delta 0.25, r2, 0.0001
      assert_in_delta 0.5, r3, 0.0001

      [r1, r2, r3] =
        Metrics.progress_across(
          section.id,
          [mod1_resource.id, mod2_resource.id, mod3_resource.id],
          [],
          1
        )
        |> Enum.map(fn {_id, progress} -> progress end)
        |> Enum.sort()

      assert_in_delta 0.2, r1, 0.0001
      assert_in_delta 0.25, r2, 0.0001
      assert_in_delta 0.5, r3, 0.0001

      [r1, r2] =
        Metrics.progress_across(section.id, [unit1_resource.id, unit2_resource.id], this_user.id)
        |> Enum.map(fn {_id, progress} -> progress end)
        |> Enum.sort()

      assert_in_delta 0.25, r1, 0.0001
      assert_in_delta 0.35, r2, 0.0001

      [r1, r2] =
        Metrics.progress_across(section.id, [unit1_resource.id, unit2_resource.id], [], 1)
        |> Enum.map(fn {_id, progress} -> progress end)
        |> Enum.sort()

      assert_in_delta 0.25, r1, 0.0001
      assert_in_delta 0.35, r2, 0.0001

      # Now create, enroll a new student and set some progress
      map = Seeder.add_user(map, %{}, :that_user)
      Seeder.add_users_to_section(map, :section, [:that_user])
      user_id = map.that_user.id

      [p1, p2, _] = map.mod1_pages
      set_progress(section.id, p1.published_resource.resource_id, user_id, 1)
      set_progress(section.id, p2.published_resource.resource_id, user_id, 1)

      [r1, r2, r3] =
        Metrics.progress_across(
          section.id,
          [mod1_resource.id, mod2_resource.id, mod3_resource.id],
          [],
          2
        )
        |> Enum.map(fn {_id, progress} -> progress end)
        |> Enum.sort()

      assert_in_delta 0.1, r1, 0.0001
      assert_in_delta 0.125, r2, 0.0001
      assert_in_delta 0.5833, r3, 0.0001

      # Finally, exclude that student and verify the previous result
      [r1, r2, r3] =
        Metrics.progress_across(
          section.id,
          [mod1_resource.id, mod2_resource.id, mod3_resource.id],
          [user_id],
          1
        )
        |> Enum.map(fn {_id, progress} -> progress end)
        |> Enum.sort()

      assert_in_delta 0.2, r1, 0.0001
      assert_in_delta 0.25, r2, 0.0001
      assert_in_delta 0.5, r3, 0.0001
    end

    test "page level progress calculation and setting", map do
      [p1, _, _] = map.mod1_pages

      map =
        map
        |> Map.put(:our_page, %{revision: p1.revision, resource: p1.resource})
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1, lifecycle_state: :active},
          :this_user,
          :our_page,
          :attempt1
        )
        |> Seeder.create_activity_attempt(
          %{attempt_number: 1, lifecycle_state: :evaluated, scoreable: true},
          :activity_a,
          :attempt1,
          :a1
        )
        |> Seeder.create_activity_attempt(
          %{attempt_number: 1, lifecycle_state: :evaluated, scoreable: true},
          :activity_b,
          :attempt1,
          :a2
        )
        |> Seeder.create_activity_attempt(
          %{attempt_number: 2, lifecycle_state: :evaluated, scoreable: true},
          :activity_b,
          :attempt1,
          :a21
        )
        |> Seeder.create_activity_attempt(
          %{attempt_number: 1, lifecycle_state: :active, scoreable: true},
          :activity_c,
          :attempt1,
          :a3
        )
        |> Seeder.create_activity_attempt(
          %{attempt_number: 1, lifecycle_state: :submitted, scoreable: true},
          :activity_d,
          :attempt1,
          :a4
        )
        |> Seeder.create_activity_attempt(
          %{attempt_number: 1, lifecycle_state: :active, scoreable: false},
          :activity_e,
          :attempt1,
          :a5
        )

      guid = map.a5.attempt_guid
      assert {:ok, :updated} = Metrics.update_page_progress(guid)

      ra = Oli.Repo.get(ResourceAccess, map.attempt1.resource_access_id)
      assert_in_delta 0.75, ra.progress, 0.0001
    end

    test "progress_for_page/3 calculates correctly", %{
      mod1_pages: mod1_pages,
      this_user: this_user,
      section: section
    } do
      [p1, _, _] = mod1_pages

      another_user = insert(:user)
      Sections.enroll(another_user.id, section.id, [ContextRoles.get_role(:context_learner)])
      set_progress(section.id, p1.published_resource.resource_id, another_user.id, 0.75)

      progress =
        Metrics.progress_for_page(section.id, [this_user.id, another_user.id], p1.resource.id)

      assert progress[this_user.id] == 0.5
      assert progress[another_user.id] == 0.75
    end

    test "progress_across_for_pages/4 calculates correctly", %{
      mod1_pages: mod1_pages,
      this_user: this_user,
      section: section
    } do
      [p1, p2, _] = mod1_pages

      another_user = insert(:user)
      Sections.enroll(another_user.id, section.id, [ContextRoles.get_role(:context_learner)])
      set_progress(section.id, p1.published_resource.resource_id, another_user.id, 0.75)
      set_progress(section.id, p2.published_resource.resource_id, another_user.id, 0.5)

      progress =
        Metrics.progress_across_for_pages(section.id, [p1.resource.id, p2.resource.id], [], 2)

      assert progress[p1.resource.id] == (0.5 + 0.75) / 2
      assert progress[p2.resource.id] == (1.0 + 0.5) / 2

      # excluding one user...
      progress_2 =
        Metrics.progress_across_for_pages(
          section.id,
          [p1.resource.id, p2.resource.id],
          [this_user.id],
          1
        )

      assert progress_2[p1.resource.id] == 0.75
      assert progress_2[p2.resource.id] == 0.5
    end
  end
end
