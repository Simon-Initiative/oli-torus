defmodule Oli.Scenarios.AuditedDirectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveTypes.ExecutionResult
  alias Oli.Scenarios.Engine

  # Directives act for the represented author, so every event carries that author and the
  # Scenario source.
  test "project directives record their events for the represented author" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    {:ok, institution} =
      Oli.Institutions.Audited.create_institution(audit_context(), %{
        name: "Scenario Institution",
        institution_email: "scenario@institution.edu",
        country_code: "US",
        institution_url: "http://scenario.institution.edu"
      })

    yaml = """
    - project:
        name: published
        title: Published
        visibility: global
        root:
          children:
            - page: "Page"

    - manipulate:
        to: published
        ops:
          - change:
              description: "Changed by a Scenario"
              allow_triggers: true

    - publish:
        to: published
        description: "Scenario publication"

    - clone:
        from: published
        name: copy
        title: Copy

    - project:
        name: section_source
        title: Section Source
        root:
          children:
            - page: "Page"

    - section:
        name: from_project
        title: From Project
        from: section_source

    - project:
        name: product_source
        title: Product Source
        root:
          children:
            - page: "Page"

    - product:
        name: product
        title: Product
        from: product_source

    - discussion_config:
        section: product
        enabled: true
        anonymous_posting: false

    - manipulate:
        to: product
        ops:
          - change:
              apply_major_updates: true

    - section:
        name: from_product
        title: From Product
        from: product

    - project:
        name: remix_source
        title: Remix Source
        root:
          children:
            - page: "Remixed"

    - section:
        name: standalone
        title: Standalone

    - remix:
        from: remix_source
        resource: "Remixed"
        section: standalone
        to: root

    # Hiding a page is a curriculum change, saved as a remix; its scheduling type is a schedule
    # update
    - manipulate:
        to: from_project
        ops:
          - revise:
              target: "Page"
              set:
                hidden: true
                scheduling_type: "@atom(due_by)"

    # A schedule gate on the section
    - gate:
        name: page_gate
        section: from_project
        target: "Page"
        type: "schedule"
        start: "2099-01-11T12:00:00Z"

    # A second publication of the section's project, applied to it
    - publish:
        to: section_source
        description: "Second publication"

    - update:
        from: section_source
        to: from_project

    # An author user becomes the represented author, so it comes last.
    - user:
        name: collaborator
        type: author
        email: collaborator@example.com

    - collaborator:
        user: collaborator
        project: published
    """

    %ExecutionResult{errors: errors, state: state} =
      yaml
      |> Oli.Scenarios.DirectiveParser.parse_yaml!()
      |> Oli.Scenarios.execute(author: author, institution: institution)

    assert errors == []

    scenario = [actor: author, source: :scenario]
    project_id = fn name -> Engine.get_project(state, name).project.id end

    for name <- ["published", "section_source", "product_source", "remix_source"] do
      assert_audited(:project_created, [project_id: project_id.(name)] ++ scenario)
    end

    assert_audited(:project_duplicated, [project_id: project_id.("copy")] ++ scenario)

    # Visibility set at creation is part of project_created; the change directive and the copy's
    # title are settings changes
    assert Engine.get_project(state, "published").project.visibility == :global

    changed =
      assert_audited(
        :project_settings_changed,
        [project_id: project_id.("published")] ++ scenario
      )

    assert Map.keys(changed.changes) == ["description"]

    assert_audited(
      :activation_settings_changed,
      [project_id: project_id.("published")] ++ scenario
    )

    retitled =
      assert_audited(:project_settings_changed, [project_id: project_id.("copy")] ++ scenario)

    assert retitled.changes["title"]["after"] == "Copy"

    # The author user directive made the collaborator the represented author.
    collaborator = Oli.Accounts.get_author_by_email("collaborator@example.com")

    assert_audited(:project_collaborator_changed,
      project_id: project_id.("published"),
      affected_author_id: collaborator.id,
      actor: collaborator,
      source: :scenario
    )

    # Publish, section, product, and remix directives publish their source when it has no
    # publication yet.
    for name <- ["published", "product_source", "remix_source"] do
      assert_audited(:project_published, [project_id: project_id.(name)] ++ scenario)
    end

    # The section's project is published again for the update directive
    assert length(
             audit_events(
               :project_published,
               [project_id: project_id.("section_source")] ++ scenario
             )
           ) == 2

    # A standalone section creates and publishes its own backing project.
    backing = Repo.get_by!(Oli.Authoring.Course.Project, title: "Standalone Project")
    assert_audited(:project_created, [project_id: backing.id] ++ scenario)
    assert_audited(:project_published, [project_id: backing.id] ++ scenario)

    # Sections from a project, from a product, and standalone, and the product itself.
    section_id = fn name -> Engine.get_section(state, name).id end

    for name <- ["from_project", "standalone"] do
      assert_audited(:section_created, [section_id: section_id.(name)] ++ scenario)
    end

    product = Engine.get_product(state, "product")

    from_product =
      assert_audited(:section_created, [section_id: section_id.("from_product")] ++ scenario)

    assert from_product.details["blueprint_id"] == product.id

    assert_audited(
      :product_created,
      [section_id: product.id, project_id: project_id.("product_source")] ++ scenario
    )

    # Template settings: course discussions and the publication update policy
    discussions =
      assert_audited(:discussion_settings_changed, [section_id: product.id] ++ scenario)

    assert discussions.changes["status"]["after"] == "enabled"
    assert discussions.changes["anonymous_posting"]["after"] == false

    assert_audited(:publication_update_policy_changed, [section_id: product.id] ++ scenario)

    # The update and remix directives
    assert_audited(
      :publication_applied,
      [section_id: section_id.("from_project"), project_id: project_id.("section_source")] ++
        scenario
    )

    assert [_ | _] =
             audit_events(
               :section_remix_saved,
               [section_id: section_id.("standalone")] ++ scenario
             )

    hidden =
      assert_audited(:section_remix_saved, [section_id: section_id.("from_project")] ++ scenario)

    assert hidden.changes["hidden"] == %{"operation" => "set", "before" => false, "after" => true}

    scheduled =
      assert_audited(
        :curriculum_schedule_changed,
        [section_id: section_id.("from_project")] ++ scenario
      )

    assert scheduled.changes["scheduling_type"]["after"] == "due_by"

    gate =
      assert_audited(:gating_changed, [section_id: section_id.("from_project")] ++ scenario)

    assert gate.changes["type"] == %{"operation" => "set", "after" => "schedule"}
  end

  test "assessment settings and student exception directives record their events" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    yaml = """
    - project:
        name: source
        title: Source
        root:
          children:
            - page: "Quiz Page"

    - edit_page:
        project: source
        page: "Quiz Page"
        content: |
          title: "Quiz Page"
          graded: true
          blocks: []

    - publish:
        to: source
        description: "Graded page"

    - section:
        name: course
        title: Course
        from: source

    - user:
        name: student_1
        type: student
        email: audited_directive_student@test.edu

    - enroll:
        user: student_1
        section: course
        role: student

    - manipulate:
        to: course
        ops:
          - revise:
              target: "Quiz Page"
              set:
                max_attempts: 4

    - student_exception:
        action: "set"
        student: student_1
        section: course
        page: "Quiz Page"
        set:
          max_attempts: 6

    - student_exception:
        action: "remove"
        student: student_1
        section: course
        page: "Quiz Page"
    """

    %ExecutionResult{errors: errors, state: state} =
      yaml
      |> Oli.Scenarios.DirectiveParser.parse_yaml!()
      |> Oli.Scenarios.execute(author: author)

    assert errors == []

    section = Engine.get_section(state, "course")
    student = state.users["student_1"]

    # The settings change acts as the section's hidden instructor, which passes the
    # secure-delivery editor check.
    settings =
      assert_audited(:assessment_settings_changed, section_id: section.id, source: :scenario)

    assert settings.changes["max_attempts"]["after"] == 4

    for event <- [:student_exception_created, :student_exception_deleted] do
      assert_audited(event,
        section_id: section.id,
        affected_user_id: student.id,
        actor: author,
        source: :scenario
      )
    end
  end
end
