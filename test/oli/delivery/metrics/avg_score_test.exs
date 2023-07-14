defmodule Oli.Delivery.Metrics.AvgScoreTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core

  defp set_score(section_id, resource_id, user_id, score, out_of, revision) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{score: score, out_of: out_of})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: :evaluated
    })
  end

  describe "average score calculations" do
    setup do
      map = Seeder.base_project_with_larger_hierarchy()
      map = Seeder.add_user(map, %{}, :user_1)
      map = Seeder.add_user(map, %{}, :user_2)
      Seeder.add_users_to_section(map, :section, [:user_1, :user_2])

      {:ok, _} = Sections.rebuild_contained_pages(map.section)

      user_1 = map.user_1.id
      user_2 = map.user_2.id
      section = map.section

      [p1, p2, p3] = map.mod1_pages
      [p4, p5, p6] = map.mod2_pages
      [p7, p8, _, _] = map.mod3_pages

      set_score(
        section.id,
        p1.published_resource.resource_id,
        user_1,
        4,
        4,
        p1.revision
      )

      set_score(
        section.id,
        p2.published_resource.resource_id,
        user_1,
        3,
        4,
        p2.revision
      )

      set_score(
        section.id,
        p3.published_resource.resource_id,
        user_1,
        2,
        4,
        p3.revision
      )

      set_score(
        section.id,
        p4.published_resource.resource_id,
        user_1,
        1,
        4,
        p4.revision
      )

      set_score(
        section.id,
        p5.published_resource.resource_id,
        user_1,
        0,
        4,
        p5.revision
      )

      set_score(
        section.id,
        p6.published_resource.resource_id,
        user_1,
        4,
        4,
        p6.revision
      )

      set_score(
        section.id,
        p7.published_resource.resource_id,
        user_1,
        4,
        4,
        p7.revision
      )

      set_score(
        section.id,
        p8.published_resource.resource_id,
        user_1,
        3,
        4,
        p8.revision
      )

      set_score(
        section.id,
        p1.published_resource.resource_id,
        user_2,
        0,
        4,
        p1.revision
      )

      set_score(
        section.id,
        p2.published_resource.resource_id,
        user_2,
        4,
        4,
        p2.revision
      )

      set_score(
        section.id,
        p3.published_resource.resource_id,
        user_2,
        1,
        4,
        p3.revision
      )

      map
    end

    test "avg_score_for/3 calculates correctly", %{
      section: section,
      user_1: user_1,
      user_2: user_2,
      mod1_resource: mod1_resource,
      mod2_resource: mod2_resource,
      mod3_resource: mod3_resource,
      unit1_resource: unit1_resource,
      unit2_resource: unit2_resource
    } do
      # Verify the modules
      module_1_avg_scores =
        Metrics.avg_score_for(
          section.id,
          [user_1.id, user_2.id],
          mod1_resource.id
        )

      module_2_avg_scores =
        Metrics.avg_score_for(
          section.id,
          [user_1.id, user_2.id],
          mod2_resource.id
        )

      module_3_avg_scores =
        Metrics.avg_score_for(
          section.id,
          [user_1.id, user_2.id],
          mod3_resource.id
        )

      assert_in_delta 0.75, Map.get(module_1_avg_scores, user_1.id), 0.0001
      assert_in_delta 0.4166, Map.get(module_2_avg_scores, user_1.id), 0.0001
      assert_in_delta 0.875, Map.get(module_3_avg_scores, user_1.id), 0.0001

      assert_in_delta 0.4166, Map.get(module_1_avg_scores, user_2.id), 0.0001
      assert Map.get(module_2_avg_scores, user_2.id) == nil
      assert Map.get(module_3_avg_scores, user_2.id) == nil

      # Then the units
      unit_1_avg_scores =
        Metrics.avg_score_for(
          section.id,
          [user_1.id, user_2.id],
          unit1_resource.id
        )

      unit_2_avg_scores =
        Metrics.avg_score_for(
          section.id,
          [user_1.id, user_2.id],
          unit2_resource.id
        )

      assert_in_delta 0.5833, Map.get(unit_1_avg_scores, user_1.id), 0.0001
      assert_in_delta 0.875, Map.get(unit_2_avg_scores, user_1.id), 0.0001

      assert_in_delta 0.4166, Map.get(unit_1_avg_scores, user_2.id), 0.0001
      assert Map.get(unit_2_avg_scores, user_2.id) == nil

      # Then the entire course
      course_avg_scores = Metrics.avg_score_for(section.id, [user_1.id, user_2.id])

      assert_in_delta 0.6562, Map.get(course_avg_scores, user_1.id), 0.0001
      assert_in_delta 0.4166, Map.get(course_avg_scores, user_2.id), 0.0001
    end

    test "avg_score_across_for_pages/3 calculates correctly",
         %{
           section: section,
           user_1: user_1,
           user_2: user_2,
           mod1_pages: mod1_pages,
           mod2_pages: mod2_pages,
           mod3_pages: mod3_pages
         } do
      [p1, p2, p3] = mod1_pages
      [p4, p5, p6] = mod2_pages
      [p7, p8, p9, p10] = mod3_pages

      pages_avg_score =
        Metrics.avg_score_across_for_pages(
          section.id,
          [
            p1.published_resource.resource_id,
            p2.published_resource.resource_id,
            p3.published_resource.resource_id,
            p4.published_resource.resource_id,
            p5.published_resource.resource_id,
            p6.published_resource.resource_id,
            p7.published_resource.resource_id,
            p8.published_resource.resource_id,
            p9.published_resource.resource_id,
            p10.published_resource.resource_id
          ],
          [user_1.id, user_2.id]
        )

      pages_avg_score_excluding_user_2 =
        Metrics.avg_score_across_for_pages(
          section.id,
          [
            p1.published_resource.resource_id,
            p2.published_resource.resource_id,
            p3.published_resource.resource_id,
            p4.published_resource.resource_id,
            p5.published_resource.resource_id,
            p6.published_resource.resource_id,
            p7.published_resource.resource_id,
            p8.published_resource.resource_id,
            p9.published_resource.resource_id,
            p10.published_resource.resource_id
          ],
          [user_1.id]
        )

      assert_in_delta 0.5,
                      Map.get(
                        pages_avg_score,
                        p1.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.875,
                      Map.get(
                        pages_avg_score,
                        p2.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.375,
                      Map.get(
                        pages_avg_score,
                        p3.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.25,
                      Map.get(
                        pages_avg_score,
                        p4.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.0,
                      Map.get(
                        pages_avg_score,
                        p5.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 1.0,
                      Map.get(
                        pages_avg_score,
                        p6.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 1.0,
                      Map.get(
                        pages_avg_score,
                        p7.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.75,
                      Map.get(
                        pages_avg_score,
                        p8.published_resource.resource_id
                      ),
                      0.0001

      assert Map.get(pages_avg_score, p9.published_resource.resource_id) == nil
      assert Map.get(pages_avg_score, p10.published_resource.resource_id) == nil

      assert_in_delta 1.0,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p1.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.75,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p2.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.5,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p3.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.25,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p4.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.0,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p5.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 1.0,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p6.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 1.0,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p7.published_resource.resource_id
                      ),
                      0.0001

      assert_in_delta 0.75,
                      Map.get(
                        pages_avg_score_excluding_user_2,
                        p8.published_resource.resource_id
                      ),
                      0.0001

      assert Map.get(
               pages_avg_score_excluding_user_2,
               p9.published_resource.resource_id
             ) == nil

      assert Map.get(
               pages_avg_score_excluding_user_2,
               p10.published_resource.resource_id
             ) == nil
    end
  end
end
