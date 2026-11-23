defmodule Oli.Utils.SeederAuditTest do
  use Oli.DataCase

  alias Oli.Publishing
  alias Oli.Seeder
  alias Oli.Utils.Seeder.Project, as: ProjectSeeder

  @setup_actor [actor: {:system, :playwright_setup}, source: :scenario]

  test "base seeds record their publications under the setup system actor" do
    %{project: project} = Seeder.base_project_with_resource4()

    assert [_first, _second] =
             audit_events(:project_published, [project_id: project.id] ++ @setup_actor)
  end

  test "publish_project/4 records the publication under the setup system actor" do
    map = Seeder.base_project_with_resource2() |> Seeder.publish_project(:project, "Seeded", :pub)

    published = assert_audited(:project_published, [project_id: map.project.id] ++ @setup_actor)
    assert published.details["publication_id"] == map.pub.id
  end

  test "ensure_published/3 records the publication under the setup system actor" do
    %{project: project} = Seeder.base_project_with_resource2()
    working = Publishing.project_working_publication(project.slug)

    ProjectSeeder.ensure_published(%{}, working)

    assert_audited(:project_published, [project_id: project.id] ++ @setup_actor)
  end

  test "schedule gates from both seeders record gating_changed under the setup system actor" do
    map = Seeder.base_project_with_resource4()

    gate =
      Seeder.create_schedule_gating_condition(
        ~U[2099-01-01 00:00:00Z],
        ~U[2099-01-02 00:00:00Z],
        map.page1.id,
        map.section_1
      )

    created = assert_audited(:gating_changed, [section_id: map.section_1.id] ++ @setup_actor)
    assert created.entity_id == to_string(gate.id)

    %{gate: seeded} =
      Oli.Utils.Seeder.Section.create_schedule_gating_condition(
        %{section: map.section_1, page: %{resource_id: map.page2.id}},
        Oli.Utils.Seeder.Utils.ref(:section),
        Oli.Utils.Seeder.Utils.ref(:page),
        ~U[2099-01-01 00:00:00Z],
        ~U[2099-01-02 00:00:00Z],
        gating_condition_tag: :gate
      )

    assert [_seeded, second] =
             audit_events(:gating_changed, [section_id: map.section_1.id] ++ @setup_actor)

    assert second.entity_id == to_string(seeded.id)
  end
end
