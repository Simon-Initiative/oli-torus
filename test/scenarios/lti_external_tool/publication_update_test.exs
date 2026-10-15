defmodule Oli.Scenarios.LtiExternalTool.PublicationUpdateTest do
  @moduledoc "Verifies publication-owned defaults and independent section choices through real workflows."

  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionResource, SectionsProjectsPublications, Updates}
  alias Oli.Delivery.Updates.{Subscriber, Worker}
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Scenarios
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks
  alias Oli.Scenarios.RuntimeOpts

  test "a major publication update initializes an added tool and preserves the section's original choice" do
    state = execute("publication_update.scenario.yaml")
    section = state.sections["draft_section"]
    assert link(section, Hooks.activity(state).resource_id).custom == state.params.draft["custom"]
    assert link(section, Hooks.activity(state, "added").resource_id).custom == %{"mode" => "new"}
    assert_current_publication(section, Hooks.latest_publication(state))
  end

  describe "missing-only initialization" do
    setup do
      state = execute("publication_update_setup.scenario.yaml")
      %{state: state, section: state.sections["draft_section"]}
    end

    test "repeated initialization preserves complete existing rows and skips absent/null selections",
         ctx do
      before = links(ctx.section)

      for _ <- 1..2 do
        {{:ok, 0}, queries} =
          capture_queries(fn -> initialize(ctx.section, ctx.state.params.draft_publication) end)

        assert [{_, 0}] =
                 Enum.filter(queries, fn {sql, _} -> String.starts_with?(sql, "SELECT") end)

        assert writes(queries) == []
        assert links(ctx.section) == before
      end

      for api <- [:current, :legacy] do
        assert {:ok, _} = apply_update(api, ctx.section, ctx.state.params.draft_publication)
      end

      assert links(ctx.section) == before
    end

    test "initialization uses one discovery query, one bulk write, and transfers only missing non-null selections",
         ctx do
      for name <- ["unconfigured", "cleared"] do
        assert {:ok, _} = save_selection(ctx.state, name, selection(name))
      end

      publication = publish(ctx.state)
      {{:ok, 2}, queries} = capture_queries(fn -> initialize(ctx.section, publication) end)

      assert [{_, 2}] =
               Enum.filter(queries, fn {sql, _} -> String.starts_with?(sql, "SELECT") end)

      assert [{sql, 2}] = writes(queries)
      assert String.starts_with?(sql, ~s(INSERT INTO "lti_section_resource_deep_links"))

      {{:ok, 0}, queries} = capture_queries(fn -> initialize(ctx.section, publication) end)

      assert [{_, 0}] =
               Enum.filter(queries, fn {sql, _} -> String.starts_with?(sql, "SELECT") end)

      assert writes(queries) == []
    end

    for api <- [:current, :legacy] do
      @api api
      test "#{api} reapplies the same publication through normal processing and fills missing links",
           ctx do
        id = Hooks.activity(ctx.state).resource_id

        assert {:ok, _} =
                 PlatformExternalTools.delete_section_resource_deep_link(link(ctx.section, id))

        before = snapshot(ctx.section)

        {{:ok, _}, queries} =
          capture_queries(fn ->
            apply_update(@api, ctx.section, ctx.state.params.draft_publication)
          end)

        assert Enum.any?(writes(queries), fn {sql, count} ->
                 String.starts_with?(sql, ~s(INSERT INTO "lti_section_resource_deep_links")) and
                   count == 1
               end)

        assert Enum.any?(writes(queries), fn {sql, _} ->
                 String.contains?(sql, ~s("section_resources"))
               end)

        assert Enum.sort(Enum.map(snapshot(ctx.section).resources, & &1.resource_id)) ==
                 Enum.sort(Enum.map(before.resources, & &1.resource_id))

        assert_current_publication(ctx.section, ctx.state.params.draft_publication)
        assert link(ctx.section, id).custom == ctx.state.params.draft["custom"]
      end

      test "#{api} applies an unchanged publication through normal processing", ctx do
        publication = publish(ctx.state)
        assert publication.id != ctx.state.params.draft_publication.id

        assert Publishing.get_publication_diff(ctx.state.params.draft_publication, publication).classification ==
                 :no_changes

        before = snapshot(ctx.section)

        {{:ok, _}, queries} =
          capture_queries(fn -> apply_update(@api, ctx.section, publication) end)

        assert Enum.any?(writes(queries), fn {sql, _} ->
                 String.contains?(sql, ~s("section_resources"))
               end)

        assert Enum.sort(Enum.map(snapshot(ctx.section).resources, & &1.resource_id)) ==
                 Enum.sort(Enum.map(before.resources, & &1.resource_id))

        assert links(ctx.section) == before.links
        assert_current_publication(ctx.section, publication)
      end
    end

    test "the worker fills an existing unconfigured activity from the applied snapshot, not the newer draft",
         ctx do
      selected = selection("published")
      assert {:ok, _} = save_selection(ctx.state, "unconfigured", selected)
      publication = publish(ctx.state)

      assert Publishing.get_publication_diff(ctx.state.params.draft_publication, publication).classification ==
               :minor

      assert {:ok, _} = save_selection(ctx.state, "unconfigured", selection("unpublished"))
      before = link(ctx.section, Hooks.activity(ctx.state).resource_id)

      assert {:ok, _} = Worker.perform_now(ctx.section.slug, publication.id)

      assert link(ctx.section, Hooks.activity(ctx.state, "unconfigured").resource_id).custom ==
               selected["custom"]

      assert link(ctx.section, Hooks.activity(ctx.state).resource_id) == before
      assert_current_publication(ctx.section, publication)
    end

    test "existing instructor values survive changed, cleared and invalid replacement defaults",
         ctx do
      id = Hooks.activity(ctx.state).resource_id

      assert {:ok, _} =
               PlatformExternalTools.upsert_section_resource_deep_link(%{
                 "section_id" => ctx.section.id,
                 "resource_id" => id,
                 "type" => "ltiResourceLink",
                 "url" => "https://tool.example/instructor",
                 "custom" => %{"mode" => "instructor"}
               })

      before = link(ctx.section, id)

      for replacement <- [selection("changed"), nil, %{"type" => "invalid"}] do
        revision = Hooks.activity(ctx.state)
        assert {:ok, revision} = Hooks.save_content(ctx.state, revision.content)
        # Deliberately exercise cleared and malformed legacy publication data.
        assert {:ok, _} =
                 Resources.update_revision(revision, %{
                   content: Map.put(revision.content, "deepLink", replacement)
                 })

        publication = publish(ctx.state)

        assert {:ok, _} =
                 Updates.apply_publication_update(Repo.reload!(ctx.section), publication.id)

        assert link(ctx.section, id) == before
      end
    end

    test "invalid missing candidates roll back all initialization", ctx do
      assert {:ok, _} = save_selection(ctx.state, "unconfigured", selection("valid"))
      revision = Hooks.activity(ctx.state, "cleared")

      assert {:ok, _} =
               Resources.update_revision(revision, %{
                 content: Map.put(revision.content, "deepLink", %{"type" => "invalid"})
               })

      before = links(ctx.section)

      assert {:error, :invalid_lti_deep_link_selection} =
               initialize(ctx.section, publish(ctx.state))

      assert links(ctx.section) == before
    end

    test "a conflicting write between discovery and insertion wins unchanged", ctx do
      id = Hooks.activity(ctx.state, "unconfigured").resource_id
      assert {:ok, _} = save_selection(ctx.state, "unconfigured", selection("default"))
      publication = publish(ctx.state)
      # Introduce a real competing insert at the write boundary, after candidate discovery.
      Repo.query!("""
      CREATE FUNCTION pg_temp.insert_lti_choice_first() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF pg_trigger_depth() = 1 THEN
          INSERT INTO lti_section_resource_deep_links
            (section_id, resource_id, type, url, custom, inserted_at, updated_at)
          VALUES (NEW.section_id, NEW.resource_id, 'ltiResourceLink',
            'https://tool.example/winner', '{"mode":"winner"}', NEW.inserted_at, NEW.updated_at);
        END IF;
        RETURN NEW;
      END; $$
      """)

      Repo.query!("""
      CREATE TRIGGER insert_lti_choice_first BEFORE INSERT ON lti_section_resource_deep_links
      FOR EACH ROW EXECUTE FUNCTION pg_temp.insert_lti_choice_first()
      """)

      assert {:ok, 0} = initialize(ctx.section, publication)
      assert link(ctx.section, id).custom == %{"mode" => "winner"}
      assert length(links(ctx.section)) == 2
    end

    test "publication initialization follows final destination membership", ctx do
      id = Hooks.activity(ctx.state, "unconfigured").resource_id
      assert {:ok, _} = save_selection(ctx.state, "unconfigured", selection("excluded"))
      publication = publish(ctx.state)
      destination = Repo.get_by!(SectionResource, section_id: ctx.section.id, resource_id: id)
      # Reproduce a destination filter independently of the source publication.
      Repo.delete!(destination)

      assert {:ok, 0} = initialize(ctx.section, publication)
      assert link(ctx.section, id) == nil
      assert Repo.get_by(SectionResource, section_id: ctx.section.id, resource_id: id) == nil
    end

    test "blueprint-backed updates initialize from the applied publication", ctx do
      state =
        apply_directive(ctx.state, """
        - product:
            name: template
            from: deep_linking_project
        """)

      state =
        apply_directive(state, """
        - section:
            name: template_course
            from: template
        """)

      section = state.sections["template_course"] |> Repo.preload(:blueprint)
      assert {:ok, _} = save_selection(state, "unconfigured", selection("template-update"))
      publication = publish(state)

      assert {:ok, _} = Updates.apply_publication_update(section, publication.id)

      assert link(section, Hooks.activity(state, "unconfigured").resource_id).custom ==
               %{"mode" => "template-update"}

      assert_current_publication(section, publication)
    end

    test "remixed publication updates initialize only the matching destination resources", ctx do
      state =
        apply_directive(ctx.state, """
        - project:
            name: primary
            root:
              children:
                - page: Welcome
        """)

      state =
        apply_directive(state, """
        - section:
            name: remixed_course
            from: primary
        """)

      state =
        apply_directive(state, """
        - remix:
            section: remixed_course
            from: deep_linking_project
            resource: Tool Lesson
            to: root
        """)

      section = state.sections["remixed_course"]

      primary_publication =
        Sections.get_current_publication(section.id, state.projects["primary"].project.id)

      assert {:ok, _} = save_selection(state, "unconfigured", selection("remixed"))
      publication = publish(state)

      assert {:ok, _} = Updates.apply_publication_update(section, publication.id)

      assert link(section, Hooks.activity(state, "unconfigured").resource_id).custom == %{
               "mode" => "remixed"
             }

      assert_current_publication(section, primary_publication)
      assert_current_publication(section, publication)
      assert links(ctx.section) |> length() == 1
    end

    for api <- [:current, :legacy], major? <- [false, true] do
      @api api
      @major major?
      test "#{api} #{if major?, do: "major", else: "minor"} update rolls back resources/publication on a failed insert",
           ctx do
        assert {:ok, _} = save_selection(ctx.state, "unconfigured", selection("reject"))

        if @major do
          # A hierarchy addition makes the publication classification major.
          apply_directive(ctx.state, """
          - manipulate:
              to: deep_linking_project
              ops:
                - add_page:
                    title: Added rollback page
          """)
        end

        publication = publish(ctx.state)

        assert Publishing.get_publication_diff(ctx.state.params.draft_publication, publication).classification ==
                 if(@major, do: :major, else: :minor)

        before = snapshot(ctx.section)
        Subscriber.subscribe_to_update_progress(ctx.section.id)

        Repo.query!("""
        ALTER TABLE lti_section_resource_deep_links ADD CONSTRAINT reject_lti_initialization
        CHECK (url IS DISTINCT FROM 'https://tool.example/reject')
        """)

        result = apply_update(@api, ctx.section, publication)

        assert {:error, _} = result
        assert snapshot(ctx.section) == before
        refute_received {:update_progress, _, _, :complete}

        Repo.query!(
          "ALTER TABLE lti_section_resource_deep_links DROP CONSTRAINT reject_lti_initialization"
        )

        result = apply_update(@api, ctx.section, publication)

        assert {:ok, _} = result

        assert link(ctx.section, Hooks.activity(ctx.state, "unconfigured").resource_id).custom ==
                 %{"mode" => "reject"}

        assert_current_publication(ctx.section, publication)
        assert Repo.aggregate(Section, :count) == before.section_count
      end
    end
  end

  defp execute(name) do
    path = Path.join(__DIR__, name)
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, RuntimeOpts.build())
    assert result.errors == [], inspect(result.errors)
    assert Enum.all?(result.verifications, & &1.passed)
    result.state
  end

  defp apply_directive(state, yaml) do
    [directive] = Oli.Scenarios.DirectiveParser.parse_yaml!(yaml)
    assert {:ok, updated} = Oli.Scenarios.Engine.execute_directive(directive, state)
    updated
  end

  defp save_selection(state, activity, selected),
    do:
      Hooks.save_content(
        state,
        Map.put(Hooks.activity(state, activity).content, "deepLink", selected),
        activity
      )

  defp selection(mode),
    do: %{
      "type" => "ltiResourceLink",
      "url" => "https://tool.example/#{mode}",
      "custom" => %{"mode" => mode}
    }

  defp publish(state) do
    assert {:ok, publication} =
             Publishing.publish_project(
               Hooks.project(state),
               "Tool update",
               state.current_author.id
             )

    publication
  end

  defp initialize(section, publication),
    do: PlatformExternalTools.initialize_section_deep_links(section.id, publication.id)

  defp apply_update(:current, section, publication),
    do: Updates.apply_publication_update(section, publication.id)

  defp apply_update(:legacy, section, publication),
    do: Sections.apply_publication_update(section, publication.id)

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

  defp assert_current_publication(section, publication),
    do:
      assert(
        Sections.get_current_publication(section.id, publication.project_id).id == publication.id
      )

  defp snapshot(section) do
    %{
      section: Repo.get!(Section, section.id),
      resources:
        Repo.all(from r in SectionResource, where: r.section_id == ^section.id, order_by: r.id),
      publications:
        Repo.all(
          from p in SectionsProjectsPublications,
            where: p.section_id == ^section.id,
            order_by: p.project_id
        ),
      links: links(section),
      section_count: Repo.aggregate(Section, :count)
    }
  end

  defp capture_queries(operation) do
    id = "deep-link-initialization-#{System.unique_integer([:positive])}"
    ref = make_ref()
    owner = self()

    :ok =
      :telemetry.attach(
        id,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          case {self() == owner, metadata.result} do
            {true, {:ok, %{num_rows: count}}} -> send(owner, {ref, {metadata.query, count}})
            _ -> :ok
          end
        end,
        nil
      )

    try do
      result = operation.()
      {result, collect_queries(ref, [])}
    after
      :telemetry.detach(id)
    end
  end

  defp collect_queries(ref, acc) do
    receive do
      {^ref, query} -> collect_queries(ref, [query | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp writes(queries),
    do: Enum.filter(queries, fn {sql, _} -> Regex.match?(~r/^(INSERT|UPDATE|DELETE)\b/, sql) end)
end
