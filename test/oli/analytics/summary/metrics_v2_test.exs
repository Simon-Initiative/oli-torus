defmodule Oli.Analytics.Summary.MetricsV2Test do
  use Oli.DataCase

  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Metrics

  describe "v2 metrics calculations" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_objective("objective two", :o2)
        |> Seeder.add_objective("objective three", :o3)
        |> Seeder.add_activity(%{title: "one", content: %{}}, :a1)
        |> Seeder.add_activity(%{title: "two", content: %{}}, :a2)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)

      Seeder.create_section_resources(map)
    end

    test "proficiency for objectives", %{
      user1: user1,
      user2: user2,
      section: section,
      o1: o1,
      o2: o2,
      page1: page1,
      project: project
    } do
      objective_type_id = Oli.Resources.ResourceType.id_for_objective()
      page_type_id = Oli.Resources.ResourceType.id_for_page()
      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{analytics_version: :v2})

      id = o1.resource.id
      id2 = o2.resource.id

      [
        # page record
        [-1, -1, section.id, -1, page1.id, nil, page_type_id, 4, 10, 1, 5, 1],
        [-1, -1, section.id, -1, id, nil, objective_type_id, 4, 10, 1, 5, 1],
        [-1, -1, section.id, user1.id, id, nil, objective_type_id, 2, 6, 1, 1, 0],
        [-1, -1, section.id, user2.id, id, nil, objective_type_id, 2, 4, 0, 1, 1],
        [project.id, -1, -1, -1, id, nil, objective_type_id, 4, 10, 1, 5, 1],
        [-1, -1, section.id, -1, id2, nil, objective_type_id, 40, 100, 55, 50, 10],
        [-1, -1, section.id, user1.id, id2, nil, objective_type_id, 2, 6, 1, 3, 1],
        [-1, -1, section.id, user2.id, id2, nil, objective_type_id, 2, 4, 0, 4, 2],
        [project.id, -1, -1, -1, id2, nil, objective_type_id, 4, 10, 1, 5, 1]
      ]
      |> Enum.each(fn v -> add_resource_summary(v) end)

      results = Metrics.raw_proficiency_per_learning_objective(section.id)
      assert Map.keys(results) |> Enum.count() == 2
      assert assert %{^id => {1, 5, 4, 10}, ^id2 => {10, 50, 40, 100}} = results

      assert %{^id => {0, 1, 2, 6}, ^id2 => {1, 3, 2, 6}} =
               Metrics.raw_proficiency_per_learning_objective(section.id, student_id: user1.id)

      assert %{^id => {1, 1, 2, 4}, ^id2 => {2, 4, 2, 4}} =
               Metrics.raw_proficiency_per_learning_objective(section.id, student_id: user2.id)
    end

    test "proficiency for page", %{
      user1: user1,
      user2: user2,
      section: section,
      o1: o1,
      page1: page1,
      page2: page2,
      project: project
    } do
      objective_type_id = Oli.Resources.ResourceType.id_for_objective()
      page_type_id = Oli.Resources.ResourceType.id_for_page()
      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{analytics_version: :v2})

      id = o1.resource.id

      page1_id = page1.id
      page2_id = page2.id

      user1_id = user1.id
      user2_id = user2.id

      [
        # page records
        [-1, -1, section.id, -1, page1.id, nil, page_type_id, 4, 10, 1, 5, 1],
        [-1, -1, section.id, -1, page2.id, nil, page_type_id, 3, 11, 2, 3, 2],
        [-1, -1, section.id, user1.id, page1.id, nil, page_type_id, 2, 10, 1, 5, 1],
        [-1, -1, section.id, user1.id, page2.id, nil, page_type_id, 4, 11, 2, 30, 30],
        [-1, -1, section.id, user2.id, page1.id, nil, page_type_id, 1, 12, 3, 5, 1],
        [-1, -1, section.id, user2.id, page2.id, nil, page_type_id, 2, 14, 4, 3, 2],
        # objective records
        [-1, -1, section.id, -1, id, nil, objective_type_id, 4, 10, 1, 5, 1],
        [-1, -1, section.id, user1.id, id, nil, objective_type_id, 2, 6, 1, 1, 0],
        [-1, -1, section.id, user2.id, id, nil, objective_type_id, 2, 4, 0, 1, 1],
        [project.id, -1, -1, -1, id, nil, objective_type_id, 4, 10, 1, 5, 1]
      ]
      |> Enum.each(fn v -> add_resource_summary(v) end)

      results = Metrics.proficiency_for_student_per_page(section, user1.id)

      assert Map.keys(results) |> Enum.count() == 2
      assert %{^page1_id => "Low", ^page2_id => "High"} = results

      results = Metrics.proficiency_per_student_for_page(section, page1_id)
      assert Map.keys(results) |> Enum.count() == 2
      assert %{^user1_id => "Low", ^user2_id => "Low"} = results

      results = Metrics.proficiency_per_page(section, [page1_id, page2_id])
      assert Map.keys(results) |> Enum.count() == 2
      assert %{^page1_id => "Low", ^page2_id => "Medium"} = results

      contained_pages = [
        %ContainedPage{container_id: 3, page_id: page1_id},
        %ContainedPage{container_id: 3, page_id: page2_id},
        %ContainedPage{container_id: 2, page_id: page1_id}
      ]

      results = Metrics.proficiency_for_student_per_container(section, user1_id, contained_pages)
      assert Map.keys(results) |> Enum.count() == 2
      assert %{2 => "Low", 3 => "High"} = results

      results = Metrics.proficiency_per_container(section, contained_pages)
      assert Map.keys(results) |> Enum.count() == 2
      assert %{2 => "Low", 3 => "Medium"} = results

      results = Metrics.proficiency_per_student_across(section)
      assert Map.keys(results) |> Enum.count() == 2
      assert %{^user1_id => "High", ^user2_id => "Medium"} = results
    end

    test "proficiency_for_student_per_learning_objective/3 shows Not enough data when num first attempts is < 3",
         %{
           user1: user1,
           user2: user2,
           section: section,
           o1: o1,
           o2: o2,
           o3: o3
         } do
      objective_type_id = Oli.Resources.ResourceType.id_for_objective()
      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{analytics_version: :v2})

      id = o1.resource.id
      id2 = o2.resource.id
      id3 = o3.resource.id

      [
        [-1, -1, section.id, user1.id, id, nil, objective_type_id, 2, 6, 1, 1, 0],
        [-1, -1, section.id, user1.id, id2, nil, objective_type_id, 2, 6, 1, 3, 2],
        [-1, -1, section.id, user1.id, id3, nil, objective_type_id, 2, 6, 1, 3, 3],
        [-1, -1, section.id, user2.id, id, nil, objective_type_id, 2, 4, 0, 1, 1],
        [-1, -1, section.id, user2.id, id2, nil, objective_type_id, 2, 4, 0, 4, 2]
      ]
      |> Enum.each(fn v -> add_resource_summary(v) end)

      results =
        Metrics.proficiency_for_student_per_learning_objective(
          [o1.revision, o2.revision, o3.revision],
          user1.id,
          section
        )

      assert Map.keys(results) |> Enum.count() == 3
      assert Map.get(results, id) == "Not enough data"
      assert Map.get(results, id2) == "Medium"
      assert Map.get(results, id3) == "High"
    end

    test "proficiency_for_student_per_learning_objective/3", %{
      user1: user1,
      user2: user2,
      section: section,
      o1: o1,
      o2: o2,
      o3: o3
    } do
      objective_type_id = Oli.Resources.ResourceType.id_for_objective()
      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{analytics_version: :v2})

      id = o1.resource.id
      id2 = o2.resource.id
      id3 = o3.resource.id

      [
        [-1, -1, section.id, user1.id, id, nil, objective_type_id, 1, 6, 1, 3, 0],
        [-1, -1, section.id, user1.id, id2, nil, objective_type_id, 3, 6, 1, 3, 2],
        [-1, -1, section.id, user1.id, id3, nil, objective_type_id, 6, 6, 1, 3, 3],
        [-1, -1, section.id, user2.id, id, nil, objective_type_id, 1, 4, 0, 1, 0],
        [-1, -1, section.id, user2.id, id2, nil, objective_type_id, 2, 4, 0, 4, 2]
      ]
      |> Enum.each(fn v -> add_resource_summary(v) end)

      results =
        Metrics.proficiency_for_student_per_learning_objective(
          [o1.revision, o2.revision, o3.revision],
          user1.id,
          section
        )

      assert Map.keys(results) |> Enum.count() == 3
      assert Map.get(results, id) == "Low"
      assert Map.get(results, id2) == "Medium"
      assert Map.get(results, id3) == "High"
    end

    test "proficiency_per_student_for_objective/2", %{
      user1: user1,
      user2: user2,
      section: section,
      o1: o1,
      o2: o2,
      o3: o3
    } do
      objective_type_id = Oli.Resources.ResourceType.id_for_objective()
      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{analytics_version: :v2})

      id = o1.resource.id
      id2 = o2.resource.id
      id3 = o3.resource.id

      # project_id, publication_id, section_id, user_id, resource_id,
      # part_id, resource_type_id, num_correct, num_attempts, num_hints,
      # num_first_attempts, num_first_attempts_correct
      [
        [-1, -1, section.id, user1.id, id, nil, objective_type_id, 1, 6, 1, 3, 0],
        [-1, -1, section.id, user1.id, id2, nil, objective_type_id, 3, 6, 1, 3, 2],
        [-1, -1, section.id, user1.id, id3, nil, objective_type_id, 6, 6, 1, 3, 3],
        [-1, -1, section.id, user2.id, id, nil, objective_type_id, 1, 4, 0, 1, 0],
        [-1, -1, section.id, user2.id, id2, nil, objective_type_id, 2, 4, 0, 4, 2]
      ]
      |> Enum.each(fn v -> add_resource_summary(v) end)

      proficiencies_objective1 =
        Map.get(Metrics.proficiency_per_student_for_objective(section.id, [id]), id)

      proficiencies_objective2 =
        Map.get(Metrics.proficiency_per_student_for_objective(section.id, [id2]), id2)

      proficiencies_objective3 =
        Map.get(Metrics.proficiency_per_student_for_objective(section.id, [id3]), id3)

      assert Map.get(proficiencies_objective1, user1.id) == "Low"
      assert Map.get(proficiencies_objective1, user2.id) == "Not enough data"
      assert Map.get(proficiencies_objective2, user1.id) == "Medium"
      assert Map.get(proficiencies_objective2, user2.id) == "Medium"
      assert Map.get(proficiencies_objective3, user1.id) == "High"
      refute Map.get(proficiencies_objective3, user2.id)
    end
  end
end
