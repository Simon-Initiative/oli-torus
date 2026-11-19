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
  end
end
