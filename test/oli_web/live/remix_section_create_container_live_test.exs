defmodule OliWeb.RemixSectionCreateContainerTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Hierarchy
  alias Oli.Publishing.AuthoringResolver

  import Oli.Test.HierarchyBuilder

  describe "create container buttons" do
    setup [:setup_product_creator_session]

    test "Create button appears on product remix page", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/authoring/products/#{ctx.section.slug}/remix")

      assert has_element?(view, "#create-container-button")
    end

    test "button label matches hierarchy level", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/authoring/products/#{ctx.section.slug}/remix")

      # At root level — should offer to create at the top container level
      assert has_element?(view, "#create-container-button", "Create Unit")
    end
  end

  describe "create container interaction" do
    setup [:setup_product_creator_session]

    test "clicking create adds a new container to the hierarchy list", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/authoring/products/#{ctx.section.slug}/remix")

      entries_before = view |> render() |> count_entries()

      render_click(view, "create_container", %{"type" => "unit"})

      assert view |> render() |> count_entries() == entries_before + 1
    end

    test "creating a container sets unsaved changes state", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/authoring/products/#{ctx.section.slug}/remix")

      # Save button initially disabled
      assert has_element?(view, "#save[disabled]")

      render_click(view, "create_container", %{"type" => "unit"})

      # Save button now enabled
      refute has_element?(view, "#save[disabled]")
    end

    test "save after creating container persists it", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/authoring/products/#{ctx.section.slug}/remix")

      sr_count_before =
        Repo.aggregate(
          from(sr in SectionResource, where: sr.section_id == ^ctx.section.id),
          :count
        )

      render_click(view, "create_container", %{"type" => "unit"})

      # Save stays on page with flash
      assert render_click(view, "save") =~ "Your work has been saved."

      sr_count_after =
        Repo.aggregate(
          from(sr in SectionResource, where: sr.section_id == ^ctx.section.id),
          :count
        )

      # One new SectionResource was created for the container
      assert sr_count_after == sr_count_before + 1
    end

    test "cancel after creating container does not persist it", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/authoring/products/#{ctx.section.slug}/remix")

      sr_count_before =
        Repo.aggregate(
          from(sr in SectionResource, where: sr.section_id == ^ctx.section.id),
          :count
        )

      render_click(view, "create_container", %{"type" => "unit"})

      # Cancel and confirm
      render_click(view, "cancel")
      assert {:error, {:live_redirect, _}} = render_click(view, "ok_cancel_modal")

      # No new SectionResource was created (draft was in-memory only)
      sr_count_after =
        Repo.aggregate(
          from(sr in SectionResource, where: sr.section_id == ^ctx.section.id),
          :count
        )

      assert sr_count_after == sr_count_before
    end
  end

  describe "scope isolation through LiveView" do
    setup [:setup_product_creator_session]

    test "container created in product remix does NOT appear in project authoring curriculum",
         ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/authoring/products/#{ctx.section.slug}/remix")

      # Create and save the container
      render_click(view, "create_container", %{"type" => "unit"})
      render_click(view, "save")

      # Check the project-level authoring hierarchy
      hierarchy = AuthoringResolver.full_hierarchy(ctx.project.slug)
      all_titles = Hierarchy.flatten_hierarchy(hierarchy) |> Enum.map(& &1.revision.title)

      # Even after saving, the blueprint-scoped container must be
      # invisible to project-level authoring views
      refute "Unit 2" in all_titles
    end
  end

  # --- Setup Helpers ---

  defp setup_product_creator_session(%{conn: conn}) do
    author = insert(:author)
    project = insert(:project, authors: [author])
    publication = insert(:publication, project: project, published: nil)

    _tree =
      build_hierarchy(
        project,
        publication,
        author,
        {:container, "Root",
         [
           {:container, "Unit 1",
            [
              {:container, "Module 1",
               [
                 {:page, "Page A"},
                 {:page, "Page B"}
               ]}
            ]}
         ]}
      )

    publication = Repo.get!(Oli.Publishing.Publications.Publication, publication.id)

    section = insert(:section, type: :blueprint, base_project: project)
    {:ok, section} = Sections.create_section_resources(section, publication)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> log_in_author(author)

    %{conn: conn, section: section, project: project, author: author}
  end

  defp count_entries(html) do
    # Count entry elements rendered in the curriculum list
    html
    |> Floki.parse_document!()
    |> Floki.find("[id^='entry-']")
    |> length()
  end
end
