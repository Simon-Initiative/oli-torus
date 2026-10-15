defmodule Oli.Scenarios.LtiExternalTool.InheritanceTest do
  @moduledoc "Verifies independent tool selections across template and previous-section copies."

  use Oli.DataCase

  alias Oli.Authoring.Clone
  alias Oli.Delivery
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.SectionCreationRequest
  alias Oli.Delivery.Sections

  alias Oli.Delivery.Sections.{
    Blueprint,
    CopyOptions,
    Section,
    SectionResource,
    SectionSpecification,
    Updates
  }

  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Scenarios
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks
  alias Oli.Scenarios.RuntimeOpts

  @fields [:type, :url, :custom, :title, :text]

  setup do
    path = Path.join(__DIR__, "inheritance_setup.scenario.yaml")
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, RuntimeOpts.build())
    assert result.errors == [], inspect(result.errors)
    assert Enum.all?(result.verifications, & &1.passed)

    %{
      state: result.state,
      template: result.state.products["template"],
      source: result.state.sections["source_course"]
    }
  end

  test "templates use published selections, skip absent/null values and isolate later drafts",
       ctx do
    id = Hooks.activity(ctx.state).resource_id
    assert link(ctx.template, id).custom == ctx.state.params.draft["custom"]
    assert length(links(ctx.template)) == 1

    for name <- ["unconfigured", "cleared"] do
      assert link(ctx.template, Hooks.activity(ctx.state, name).resource_id) == nil
    end

    assert {:ok, _} = save_selection(ctx.state, "configured", selection("draft-only"))

    assert {:ok, older} =
             Blueprint.create_blueprint(Hooks.project(ctx.state).slug, "Older snapshot", %{})

    assert values(link(older, id)) == values(link(ctx.template, id))

    publish(ctx.state)

    assert {:ok, newer} =
             Blueprint.create_blueprint(Hooks.project(ctx.state).slug, "New snapshot", %{})

    assert link(newer, id).custom == %{"mode" => "draft-only"}
    assert values(link(ctx.template, id)) == values(link(ctx.source, id))
  end

  test "template copies preserve current portable metadata and are independently editable", ctx do
    id = Hooks.activity(ctx.state).resource_id

    chosen =
      selection("template")
      |> Map.put("url", "https://tool.example/" <> String.duplicate("x", 400))
      |> Map.put("title", String.duplicate("título ", 80))
      |> Map.put("text", String.duplicate("description ", 100))
      |> Map.put("custom", %{"nested" => %{"ids" => [1, 2]}, "task_json" => "{\"id\":\"task\"}"})

    assert {:ok, _} = put_selection(ctx.template, id, chosen)
    assert {:ok, _} = save_selection(ctx.state, "configured", selection("new-project-default"))
    publish(ctx.state)

    assert {:ok, destination} = create_copy(ctx.state, ctx.template, :product)
    assert_same_selection(ctx.template, destination, id)
    assert link(ctx.source, id).custom == ctx.state.params.draft["custom"]
    assert {:ok, _} = put_selection(destination, id, selection("destination"))
    assert link(ctx.template, id).custom == chosen["custom"]
    assert {:ok, _} = put_selection(ctx.template, id, selection("template-later"))
    assert link(destination, id).custom == %{"mode" => "destination"}
  end

  for {kind, groups} <- [{:content_only, [:content]}, {:all_groups, CopyOptions.groups()}] do
    @groups groups
    test "#{kind} previous-section copies include instructor selections, provenance and independent publication pins",
         ctx do
      id = Hooks.activity(ctx.state).resource_id
      assert {:ok, _} = put_selection(ctx.source, id, selection("instructor"))
      assert {:ok, copy} = create_copy(ctx.state, ctx.source, :section, @groups)
      assert_same_selection(ctx.source, copy, id)
      assert copy.base_project_id == ctx.source.base_project_id
      assert copy.blueprint_id == ctx.source.blueprint_id
      assert copy.blueprint_id != ctx.source.id
      assert pins(copy) == pins(ctx.source)

      assert {:ok, _} = put_selection(copy, id, selection("copied-course"))
      assert link(ctx.source, id).custom == %{"mode" => "instructor"}
      assert {:ok, _} = put_selection(ctx.source, id, selection("source-later"))
      assert link(copy, id).custom == %{"mode" => "copied-course"}

      added_id = Hooks.activity(ctx.state, "unconfigured").resource_id
      assert {:ok, _} = save_selection(ctx.state, "unconfigured", selection("newly-published"))
      publication = publish(ctx.state)

      assert {:ok, _} =
               Updates.apply_publication_update(Repo.preload(copy, :blueprint), publication.id)

      assert link(copy, added_id).custom == %{"mode" => "newly-published"}
      assert link(copy, id).custom == %{"mode" => "copied-course"}
      assert link(ctx.source, added_id) == nil
      assert pins(ctx.source) != pins(copy)

      assert {:ok, _} =
               Updates.apply_publication_update(
                 Repo.preload(ctx.source, :blueprint),
                 publication.id
               )

      assert pins(copy) == pins(ctx.source)
      assert link(ctx.source, id).custom == %{"mode" => "source-later"}
    end
  end

  for kind <- [:product, :section] do
    @kind kind
    test "#{kind} copies preserve missing/cleared choices without project fallback", ctx do
      source =
        case @kind do
          :product -> ctx.template
          :section -> ctx.source
        end

      id = Hooks.activity(ctx.state).resource_id
      assert {:ok, _} = PlatformExternalTools.delete_section_resource_deep_link(link(source, id))
      assert {:ok, _} = save_selection(ctx.state, "unconfigured", selection("project-only"))
      publish(ctx.state)

      assert {:ok, copy} = create_copy(ctx.state, source, @kind)
      assert links(copy) == []
      assert links(source) == []
      assert Hooks.activity(ctx.state).content["deepLink"] != nil
    end
  end

  test "copying uses one INSERT SELECT for multiple selections", ctx do
    assert {:ok, _} =
             put_selection(
               ctx.template,
               Hooks.activity(ctx.state, "unconfigured").resource_id,
               selection("another")
             )

    assert {:ok, _} =
             PlatformExternalTools.delete_section_resource_deep_link(hd(links(ctx.source)))

    {{:ok, 2}, queries} =
      capture_queries(fn ->
        PlatformExternalTools.copy_section_deep_links(ctx.template.id, ctx.source.id)
      end)

    assert [sql] = queries
    assert String.starts_with?(sql, ~s(INSERT INTO "lti_section_resource_deep_links"))
    assert String.contains?(sql, "SELECT")

    for link <- links(ctx.template),
        do: assert_same_selection(ctx.template, ctx.source, link.resource_id)
  end

  test "copying includes only the source/destination resource intersection",
       ctx do
    for name <- ["unconfigured", "cleared"] do
      assert {:ok, _} =
               put_selection(
                 ctx.template,
                 Hooks.activity(ctx.state, name).resource_id,
                 selection(name)
               )
    end

    assert {:ok, _} =
             PlatformExternalTools.delete_section_resource_deep_link(hd(links(ctx.source)))

    delete_resource(ctx.source, Hooks.activity(ctx.state, "unconfigured").resource_id)
    delete_resource(ctx.template, Hooks.activity(ctx.state, "cleared").resource_id)

    assert {:ok, 1} =
             PlatformExternalTools.copy_section_deep_links(ctx.template.id, ctx.source.id)

    assert length(links(ctx.source)) == 1
    assert_same_selection(ctx.template, ctx.source, Hooks.activity(ctx.state).resource_id)
  end

  test "project cloning remaps template project/publication pins while preserving independent selections",
       ctx do
    id = Hooks.activity(ctx.state).resource_id
    assert {:ok, _} = put_selection(ctx.template, id, selection("template-local"))

    assert {:ok, project} =
             Clone.clone_project(Hooks.project(ctx.state).slug, ctx.state.current_author)

    [copy] = Blueprint.get_blueprint_by_base_project(project)
    assert copy.type == :blueprint
    assert copy.base_project_id == project.id
    assert copy.base_project_id != ctx.template.base_project_id
    assert_same_selection(ctx.template, copy, id)
    assert [{project.id, Publishing.project_working_publication(project.slug).id}] == pins(copy)
    assert {:ok, _} = put_selection(copy, id, selection("clone-only"))
    assert link(ctx.template, id).custom == %{"mode" => "template-local"}
  end

  test "template initialization failure rolls back the whole blueprint", ctx do
    assert {:ok, _} = save_selection(ctx.state, "configured", selection("reject"))
    publish(ctx.state)
    before = counts()
    reject_selection()

    assert {:error, :lti_deep_link_initialization_failed} =
             Blueprint.create_blueprint(Hooks.project(ctx.state).slug, "Rejected template", %{})

    assert counts() == before
  end

  for kind <- [:product, :section] do
    @kind kind
    test "#{kind} selection-copy failure rolls back all destination state and can be retried",
         ctx do
      source =
        case @kind do
          :product -> ctx.template
          :section -> ctx.source
        end

      id = Hooks.activity(ctx.state).resource_id
      assert {:ok, _} = put_selection(source, id, selection("reject"))
      before = counts()
      # Existing source data is allowed; only newly inserted rows must satisfy this constraint.
      reject_selection()
      assert {:error, :lti_deep_link_copy_failed} = create_copy(ctx.state, source, @kind)
      assert counts() == before
      assert link(source, id).custom == %{"mode" => "reject"}

      Repo.query!("ALTER TABLE lti_section_resource_deep_links DROP CONSTRAINT reject_lti_copy")
      assert {:ok, destination} = create_copy(ctx.state, source, @kind)
      assert_same_selection(source, destination, id)
    end
  end

  test "copying tool selections leaves source learner records behind", ctx do
    state =
      apply_directives(ctx.state, """
      - enroll:
          user: learner
          section: source_course
      - view_practice_page:
          student: learner
          section: source_course
          page: Tool Lesson
      """)

    assert learner_rows(ctx.source, "enrollments") > 0
    assert learner_rows(ctx.source, "resource_accesses") > 0

    before =
      Map.new(
        [ResourceAccess, ResourceAttempt, ActivityAttempt, PartAttempt],
        &{&1, Repo.aggregate(&1, :count)}
      )

    assert before[ResourceAttempt] > 0
    assert before[ActivityAttempt] > 0
    assert {:ok, copy} = create_copy(state, ctx.source, :section)
    assert_same_selection(ctx.source, copy, Hooks.activity(state).resource_id)

    for table <- ["enrollments", "resource_accesses"] do
      assert learner_rows(copy, table) == 0
    end

    for {schema, count} <- before, do: assert(Repo.aggregate(schema, :count) == count)
  end

  defp create_copy(state, source, kind, groups \\ CopyOptions.groups()) do
    assert {:ok, request} =
             SectionCreationRequest.new(
               state.current_author,
               "#{kind}:#{source.id}",
               %{title: "Inherited course"},
               SectionSpecification.direct()
             )

    assert {:ok, options} = CopyOptions.for_previous_section(groups)

    case Delivery.create_section(%{request | copy_options: options}) do
      {:ok, id, _} -> {:ok, Sections.get_section!(id)}
      error -> error
    end
  end

  defp put_selection(section, id, selected),
    do:
      PlatformExternalTools.upsert_section_resource_deep_link(
        Map.merge(selected, %{"section_id" => section.id, "resource_id" => id})
      )

  defp selection(mode),
    do: %{
      "type" => "ltiResourceLink",
      "url" => "https://tool.example/#{mode}",
      "custom" => %{"mode" => mode}
    }

  defp save_selection(state, name, selected),
    do:
      Hooks.save_content(
        state,
        Map.put(Hooks.activity(state, name).content, "deepLink", selected),
        name
      )

  defp publish(state) do
    assert {:ok, pub} =
             Publishing.publish_project(
               Hooks.project(state),
               "Inheritance update",
               state.current_author.id
             )

    pub
  end

  defp link(section, id),
    do:
      PlatformExternalTools.get_section_resource_deep_link_by(
        section_id: section.id,
        resource_id: id
      )

  defp links(section),
    do:
      Repo.all(
        from l in LtiSectionResourceDeepLink,
          where: l.section_id == ^section.id,
          order_by: l.resource_id
      )

  defp values(link), do: Map.take(link, @fields)

  defp assert_same_selection(source, copy, id) do
    original = link(source, id)
    copied = link(copy, id)
    assert copied.id != original.id
    assert copied.section_id == copy.id
    assert values(copied) == values(original)
  end

  defp pins(section),
    do:
      Repo.all(
        from p in SectionsProjectsPublications,
          where: p.section_id == ^section.id,
          order_by: p.project_id,
          select: {p.project_id, p.publication_id}
      )

  defp delete_resource(section, id),
    do: Repo.get_by!(SectionResource, section_id: section.id, resource_id: id) |> Repo.delete!()

  defp counts,
    do:
      Map.new(
        [Section, SectionResource, SectionsProjectsPublications, LtiSectionResourceDeepLink],
        &{&1, Repo.aggregate(&1, :count)}
      )

  defp reject_selection,
    do:
      Repo.query!(
        "ALTER TABLE lti_section_resource_deep_links ADD CONSTRAINT reject_lti_copy CHECK (url <> 'https://tool.example/reject') NOT VALID"
      )

  defp learner_rows(section, table),
    do: Repo.aggregate(from(r in table, where: r.section_id == ^section.id), :count)

  defp apply_directives(state, yaml) do
    Enum.reduce(Oli.Scenarios.DirectiveParser.parse_yaml!(yaml), state, fn directive, state ->
      assert {:ok, state} = Oli.Scenarios.Engine.execute_directive(directive, state)
      state
    end)
  end

  defp capture_queries(operation) do
    handler = "lti-copy-#{System.unique_integer([:positive])}"
    ref = make_ref()
    owner = self()

    :ok =
      :telemetry.attach(
        handler,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          case self() == owner do
            true -> send(owner, {ref, metadata.query})
            false -> :ok
          end
        end,
        nil
      )

    try do
      result = operation.()
      {result, collect_queries(ref, [])}
    after
      :telemetry.detach(handler)
    end
  end

  defp collect_queries(ref, queries) do
    receive do
      {^ref, sql} -> collect_queries(ref, [sql | queries])
    after
      0 -> Enum.reverse(queries)
    end
  end
end
