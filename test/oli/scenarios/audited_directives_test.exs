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
    for name <- ["published", "section_source", "product_source", "remix_source"] do
      assert_audited(:project_published, [project_id: project_id.(name)] ++ scenario)
    end

    # A standalone section creates and publishes its own backing project.
    backing = Repo.get_by!(Oli.Authoring.Course.Project, title: "Standalone Project")
    assert_audited(:project_created, [project_id: backing.id] ++ scenario)
    assert_audited(:project_published, [project_id: backing.id] ++ scenario)
  end
end
