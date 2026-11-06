defmodule Oli.Scenarios.LtiExternalTool.PublicationUpdateTest do
  @moduledoc "Verifies publication-owned defaults and independent section choices through real workflows."

  use Oli.DataCase

  import Oli.Scenarios.LtiExternalTool.DeepLinkingHelpers

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionResource, SectionsProjectsPublications, Updates}
  alias Oli.Delivery.Updates.{Subscriber, Worker}
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks

  test "a major publication update initializes an added tool and preserves the section's original choice" do
    state = execute_scenario(Path.join(__DIR__, "publication_update.scenario.yaml"))
    section = state.sections["draft_section"]
    assert link(section, Hooks.activity(state).resource_id).custom == state.params.draft["custom"]
    assert link(section, Hooks.activity(state, "added").resource_id).custom == %{"mode" => "new"}
    assert_current_publication(section, Hooks.latest_publication(state))
  end

  describe "missing-only initialization" do
    setup do
      state = execute_scenario(Path.join(__DIR__, "publication_update_setup.scenario.yaml"))
      %{state: state, section: state.sections["draft_section"]}
    end

    test "repeated initialization preserves complete existing rows and skips absent/null selections",
         ctx do
      before = links(ctx.section)

      for _ <- 1..2 do
        assert {:ok, 0} = initialize(ctx.section, ctx.state.params.draft_publication)
        assert links(ctx.section) == before
      end

      for api <- [:current, :legacy] do
        assert {:ok, _} = apply_update(api, ctx.section, ctx.state.params.draft_publication)
      end

      assert links(ctx.section) == before
    end

    test "initialization transfers only missing non-null selections",
         ctx do
      for name <- ["unconfigured", "cleared"] do
        assert {:ok, _} = save_selection(ctx.state, name, selection(name))
      end

      publication = publish(ctx.state)
      assert {:ok, 2} = initialize(ctx.section, publication)

      assert link(ctx.section, Hooks.activity(ctx.state, "unconfigured").resource_id).custom == %{
               "mode" => "unconfigured"
             }

      assert link(ctx.section, Hooks.activity(ctx.state, "cleared").resource_id).custom == %{
               "mode" => "cleared"
             }

      after_initialization = links(ctx.section)
      assert {:ok, 0} = initialize(ctx.section, publication)
      assert links(ctx.section) == after_initialization
    end

    for api <- [:current, :legacy] do
      @api api
      test "#{api} reapplies the same publication through normal processing and fills missing links",
           ctx do
        id = Hooks.activity(ctx.state).resource_id

        assert {:ok, _} =
                 PlatformExternalTools.delete_section_resource_deep_link(link(ctx.section, id))

        before = snapshot(ctx.section)

        assert {:ok, _} = apply_update(@api, ctx.section, ctx.state.params.draft_publication)

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

        assert {:ok, _} = apply_update(@api, ctx.section, publication)

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
        apply_directives(ctx.state, """
        - product:
            name: template
            from: deep_linking_project
        """)

      state =
        apply_directives(state, """
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
        apply_directives(ctx.state, """
        - project:
            name: primary
            root:
              children:
                - page: Welcome
        """)

      state =
        apply_directives(state, """
        - section:
            name: remixed_course
            from: primary
        """)

      state =
        apply_directives(state, """
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
          apply_directives(ctx.state, """
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

  defp initialize(section, publication),
    do: PlatformExternalTools.initialize_section_deep_links(section.id, publication.id)

  defp apply_update(:current, section, publication),
    do: Updates.apply_publication_update(section, publication.id)

  defp apply_update(:legacy, section, publication),
    do: Sections.apply_publication_update(section, publication.id)

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
end
