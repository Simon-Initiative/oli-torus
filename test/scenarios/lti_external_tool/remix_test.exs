defmodule Oli.Scenarios.LtiExternalTool.RemixTest do
  @moduledoc "Verifies selection inheritance through real project/template remix workflows."

  use Oli.DataCase

  import Oli.Scenarios.LtiExternalTool.DeepLinkingHelpers

  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Remix
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks

  @fields [:type, :url, :custom, :title, :text]

  setup context do
    setup_scenario(context)
  end

  defp setup_scenario(%{workflow: true}), do: %{}

  defp setup_scenario(_) do
    state = execute_scenario(Path.join(__DIR__, "remix_setup.scenario.yaml"))

    %{
      state: state,
      template: state.products["template"],
      destination: state.sections["destination_course"],
      id: Hooks.activity(state).resource_id
    }
  end

  @tag workflow: true
  test "scenario directives inherit project and template choices into both destination types" do
    state = execute_scenario(Path.join(__DIR__, "remix.scenario.yaml"))
    id = Hooks.activity(state).resource_id
    source = link(state.products["template"], id)

    for destination <- [
          state.products["destination_template"],
          state.sections["destination_course"]
        ] do
      copied = link(destination, id)
      assert Map.take(copied, @fields) == Map.take(source, @fields)
      assert copied.id != source.id
      assert copied.section_id == destination.id
    end
  end

  @tag workflow: true
  test "multiple template sources share a section lookup and retain their material origins" do
    state = execute_scenario(Path.join(__DIR__, "multiple_template_remix.scenario.yaml"))
    destination = state.sections["destination_course"]
    user = state.users["remix_instructor"] |> Repo.preload(:author)
    assert {:ok, remix} = Remix.init(destination, user)

    product_ids = Enum.map(["template", "additional_template"], &state.products[&1].id)

    sources =
      Enum.filter(
        remix.available_sources,
        &(&1.type == :product and &1.product_id in product_ids)
      )

    assert length(sources) == 2

    # Warm the normal hierarchy cache before measuring the section lookup itself.
    selections =
      Map.new(sources, fn source ->
        assert {:ok, _, hierarchy} = Remix.source_hierarchy(source.key, remix)
        assert {:ok, tuple} = Remix.selection_tuple(source, hd(hierarchy.children))
        {tuple, source.key}
      end)

    handler = "template-section-queries-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler,
        [:oli, :repo, :query],
        &__MODULE__.capture_section_query/4,
        self()
      )

    try do
      assert {:ok, remix} =
               Remix.add_materials_from_sources(remix, Map.keys(selections), selections)

      assert_received :template_section_query
      refute_received :template_section_query

      assert MapSet.new(Map.values(remix.material_sources)) ==
               MapSet.new(Enum.map(product_ids, &{:section, &1}))

      assert {:ok, _} = Remix.save(remix, state.current_author)
      assert link(destination, Hooks.activity(state).resource_id)

      assert Enum.any?(
               Hierarchy.flatten_hierarchy(remix.hierarchy),
               &(&1.resource_id ==
                   state.projects["additional_project"].id_by_title["Additional Lesson"])
             )
    after
      :telemetry.detach(handler)
    end
  end

  @doc false
  def capture_section_query(_event, _measurements, %{source: "sections"}, pid) do
    case self() == pid do
      true -> send(pid, :template_section_query)
      false -> :ok
    end
  end

  def capture_section_query(_event, _measurements, _metadata, _pid), do: :ok

  for destination_kind <- [:course, :template] do
    @destination_kind destination_kind
    test "#{destination_kind} project remix retains the chosen publication over newer draft/publication",
         ctx do
      destination = destination(ctx.state, @destination_kind)
      # Select while this publication is current; publish a different choice before saving.
      {:ok, remix} = Remix.init(destination, ctx.state.current_author)
      tuple = {ctx.state.params.draft_publication.id, page_id(ctx.state)}
      assert {:ok, remix} = Remix.add_materials(remix, [tuple])
      save_selection(ctx.state, "configured", selection("new-publication"))
      publish(ctx.state)
      save_selection(ctx.state, "configured", selection("draft-only"))

      assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
      assert link(destination, ctx.id).custom == ctx.state.params.draft["custom"]
      assert Enum.member?(pins(destination), {Hooks.project(ctx.state).id, elem(tuple, 0)})
      assert link(ctx.template, ctx.id).custom == ctx.state.params.draft["custom"]
    end
  end

  for destination_kind <- [:course, :template] do
    @destination_kind destination_kind
    test "#{destination_kind} template remix uses current source metadata and independent destination rows",
         ctx do
      ctx = %{ctx | destination: destination(ctx.state, @destination_kind)}
      chosen = rich_selection("template-current")

      remix = add_template(ctx)
      # Current means read at save, not when the picker was opened.
      put_selection(ctx.template, ctx.id, chosen)
      save_selection(ctx.state, "configured", selection("project-draft"))
      assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
      copied = link(ctx.destination, ctx.id)
      assert Map.take(copied, @fields) == Map.take(link(ctx.template, ctx.id), @fields)
      assert copied.id != link(ctx.template, ctx.id).id
      put_selection(ctx.template, ctx.id, selection("source-later"))
      assert link(ctx.destination, ctx.id) == copied
      put_selection(ctx.destination, ctx.id, selection("destination-later"))
      assert link(ctx.template, ctx.id).custom == %{"mode" => "source-later"}
    end
  end

  test "actual chosen template wins when templates share a publication", ctx do
    assert {:ok, other} =
             Oli.Delivery.Sections.Blueprint.create_blueprint(
               Hooks.project(ctx.state).slug,
               "Another template",
               %{}
             )

    # Authorize the other template through the same real community mechanism.
    state =
      ctx.state
      |> Oli.Scenarios.Engine.put_product("other_template", other)
      |> apply_directives("""
      - community:
          name: Other Remix Source
          users: [remix_instructor]
          products: [template, other_template]
      """)

    put_selection(other, ctx.id, selection("other"))
    put_selection(ctx.template, ctx.id, selection("chosen"))
    assert {:ok, _} = Remix.save(add_template(%{ctx | state: state}), state.current_author)
    assert link(ctx.destination, ctx.id).custom == %{"mode" => "chosen"}
  end

  test "template missing/cleared choices never recover publication defaults", ctx do
    assert {:ok, _} =
             PlatformExternalTools.delete_section_resource_deep_link(link(ctx.template, ctx.id))

    assert {:ok, _} = Remix.save(add_template(ctx), ctx.state.current_author)
    assert links(ctx.destination) == []
    assert Hooks.activity(ctx.state).content["deepLink"] != nil
  end

  for source <- [:project, :template] do
    @source source
    test "#{source} remix preserves existing destination selections", ctx do
      remix = add(ctx, @source)
      # Existing resource membership and selection may already belong to another remixed page.
      assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
      put_selection(ctx.destination, ctx.id, selection("instructor"))
      existing = link(ctx.destination, ctx.id)
      assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
      assert link(ctx.destination, ctx.id) == existing
    end

    test "removing newly added #{source} material before save creates no selection", ctx do
      remix = add(ctx, @source)

      page =
        Enum.find(
          Hierarchy.flatten_hierarchy(remix.hierarchy),
          &(&1.resource_id == page_id(ctx.state))
        )

      assert {:ok, remix} = Remix.remove(remix, page.uuid)
      assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
      assert links(ctx.destination) == []
      refute Enum.any?(resources(ctx.destination), &(&1.resource_id == page_id(ctx.state)))
    end

    test "#{source} inheritance failure rolls back curriculum, pins and rows and permits retry",
         ctx do
      case @source do
        :project ->
          save_selection(ctx.state, "configured", selection("reject"))
          publish(ctx.state)

        :template ->
          put_selection(ctx.template, ctx.id, selection("reject"))
      end

      remix = add(ctx, @source)
      before = {resources(ctx.destination), pins(ctx.destination), links(ctx.destination)}

      Repo.query!(
        "ALTER TABLE lti_section_resource_deep_links ADD CONSTRAINT reject_remix CHECK (url <> 'https://tool.example/reject') NOT VALID"
      )

      assert {:error, :lti_deep_link_initialization_failed} =
               Remix.save(remix, ctx.state.current_author)

      assert {resources(ctx.destination), pins(ctx.destination), links(ctx.destination)} == before
      Repo.query!("ALTER TABLE lti_section_resource_deep_links DROP CONSTRAINT reject_remix")
      assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
      assert link(ctx.destination, ctx.id).url == "https://tool.example/reject"
    end
  end

  test "reordering existing content does not backfill an unrelated missing choice", ctx do
    assert {:ok, _} = Remix.save(add(ctx, :project), ctx.state.current_author)

    assert {:ok, _} =
             PlatformExternalTools.delete_section_resource_deep_link(
               link(ctx.destination, ctx.id)
             )

    assert {:ok, remix} = Remix.init(ctx.destination, ctx.state.current_author)
    assert {:ok, remix} = Remix.reorder(remix, 0, 1)
    assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
    assert links(ctx.destination) == []
  end

  test "unknown source keys cannot be used for template inheritance", ctx do
    assert {:ok, remix} = Remix.init(ctx.destination, ctx.state.current_author)
    tuple = {ctx.state.params.draft_publication.id, page_id(ctx.state)}

    assert {:error, :unavailable_publication} =
             Remix.add_materials_from_sources(remix, [tuple], %{tuple => "product:-1"})

    assert links(ctx.destination) == []
  end

  test "adding a container retains selection provenance when its page is moved before saving",
       ctx do
    assert {:ok, remix} = Remix.init(ctx.destination, ctx.state.current_author)
    pub = ctx.state.params.draft_publication
    assert {:ok, remix} = Remix.add_materials(remix, [{pub.id, pub.root_resource_id}])
    added_container = List.last(remix.hierarchy.children)

    page =
      Enum.find(
        Hierarchy.flatten_hierarchy(added_container),
        &(&1.resource_id == page_id(ctx.state))
      )

    assert {:ok, remix} = Remix.move(remix, page.uuid, remix.hierarchy.uuid)
    assert {:ok, remix} = Remix.remove(remix, added_container.uuid)
    assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
    assert link(ctx.destination, ctx.id).custom == ctx.state.params.draft["custom"]
  end

  test "an ordinary new project's empty-content root can be remixed without any LTI activities",
       ctx do
    # The scenario builder gives roots model content; the production creation API
    # is needed here to exercise the ordinary empty-content root.
    assert {:ok, %{project: project, resource_revision: root}} =
             Oli.Authoring.Course.create_project(
               "Empty container source",
               ctx.state.current_author
             )

    assert root.content == %{}

    assert {:ok, pub} =
             Publishing.publish_project(project, "Empty root", ctx.state.current_author.id)

    assert {:ok, remix} = Remix.init(ctx.destination, ctx.state.current_author)
    assert {:ok, remix} = Remix.add_materials(remix, [{pub.id, pub.root_resource_id}])
    assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
    assert links(ctx.destination) == []
  end

  test "unreferenced publication activities are not inherited even when projected in the destination",
       ctx do
    state =
      apply_directives(ctx.state, """
      - create_activity:
          project: deep_linking_project
          title: Unused Tool
          virtual_id: unused
          type: deep_linking_test_tool
          content_format: json
          content:
            authoring:
              parts: []
            deepLink:
              type: ltiResourceLink
              url: https://tool.example/unused
      """)

    publish(state)
    assert {:ok, _} = Remix.save(add(%{ctx | state: state}, :project), state.current_author)
    unused_id = Hooks.activity(state, "unused").resource_id
    assert Enum.any?(resources(ctx.destination), &(&1.resource_id == unused_id))
    assert link(ctx.destination, unused_id) == nil
    assert link(ctx.destination, ctx.id)
  end

  test "selecting a visible template container does not inherit choices from its hidden pages",
       ctx do
    put_selection(ctx.template, ctx.id, selection("hidden-template-choice"))
    assert {:ok, source_edit} = Remix.init(ctx.template, ctx.state.current_author)

    page =
      Enum.find(
        Hierarchy.flatten_hierarchy(source_edit.hierarchy),
        &(&1.resource_id == page_id(ctx.state))
      )

    assert {:ok, source_edit} = Remix.toggle_hidden(source_edit, page.uuid)
    assert {:ok, _} = Remix.save(source_edit, ctx.state.current_author)
    user = ctx.state.users["remix_instructor"] |> Repo.preload(:author)
    assert {:ok, remix} = Remix.init(ctx.destination, user)

    source =
      Enum.find(
        remix.available_sources,
        &(&1.type == :product and &1.product_id == ctx.template.id)
      )

    assert {:ok, _, hierarchy} = Remix.source_hierarchy(source.key, remix)
    assert hierarchy.children == []
    assert {:ok, tuple} = Remix.selection_tuple(source, hierarchy)
    assert {:ok, remix} = Remix.add_materials_from_sources(remix, [tuple], %{tuple => source.key})
    assert {:ok, _} = Remix.save(remix, ctx.state.current_author)
    assert link(ctx.destination, ctx.id) == nil
  end

  for source <- [:publication, :section] do
    @source source
    test "#{source} inheritance enforces resource membership and the explicit activity scope",
         ctx do
      for name <- ["unconfigured", "cleared"] do
        id = Hooks.activity(ctx.state, name).resource_id
        save_selection(ctx.state, name, selection(name))
        put_selection(ctx.template, id, selection(name))
      end

      pub = publish(ctx.state)
      assert {:ok, _} = Remix.save(add(ctx, :project), ctx.state.current_author)

      Repo.delete_all(
        from l in LtiSectionResourceDeepLink, where: l.section_id == ^ctx.destination.id
      )

      ids =
        Enum.map(
          ["configured", "unconfigured", "cleared"],
          &Hooks.activity(ctx.state, &1).resource_id
        )

      origin =
        case @source do
          :publication -> {:publication, pub.id}
          :section -> {:section, ctx.template.id}
        end

      assert {:ok, 3} =
               PlatformExternalTools.initialize_remixed_deep_links(ctx.destination.id, %{
                 origin => ids
               })

      assert length(links(ctx.destination)) == 3

      Repo.delete_all(
        from l in LtiSectionResourceDeepLink, where: l.section_id == ^ctx.destination.id
      )

      [configured, unconfigured, cleared] = ids

      Repo.delete_all(
        from r in SectionResource,
          where: r.section_id == ^ctx.destination.id and r.resource_id == ^unconfigured
      )

      assert {:ok, 1} =
               PlatformExternalTools.initialize_remixed_deep_links(ctx.destination.id, %{
                 origin => [configured, unconfigured]
               })

      assert link(ctx.destination, configured)
      assert link(ctx.destination, unconfigured) == nil
      assert link(ctx.destination, cleared) == nil

      assert {:ok, 0} =
               PlatformExternalTools.initialize_remixed_deep_links(ctx.destination.id, %{
                 origin => [configured]
               })
    end
  end

  defp add(ctx, :template), do: add_template(ctx)

  defp add(ctx, :project) do
    assert {:ok, remix} = Remix.init(ctx.destination, ctx.state.current_author)
    pub = Hooks.latest_publication(ctx.state)
    assert {:ok, remix} = Remix.add_materials(remix, [{pub.id, page_id(ctx.state)}])
    remix
  end

  defp add_template(ctx) do
    user = ctx.state.users["remix_instructor"] |> Repo.preload(:author)
    assert {:ok, remix} = Remix.init(ctx.destination, user)

    source =
      Enum.find(
        remix.available_sources,
        &(&1.type == :product and &1.product_id == ctx.template.id)
      )

    assert source
    tuple = {ctx.state.params.draft_publication.id, page_id(ctx.state)}
    assert {:ok, remix} = Remix.add_materials_from_sources(remix, [tuple], %{tuple => source.key})
    remix
  end

  defp destination(state, :course), do: state.sections["destination_course"]
  defp destination(state, :template), do: state.products["destination_template"]
  defp page_id(state), do: state.projects["deep_linking_project"].id_by_title["Tool Lesson"]

  defp resources(section),
    do:
      Repo.all(
        from r in SectionResource, where: r.section_id == ^section.id, order_by: r.resource_id
      )
end
