defmodule OliWeb.Sections.SectionsTableModelTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Sections.SectionsTableModel
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.ColumnSpec
  alias Oli.Delivery.Sections

  import Oli.Factory

  defp rendered_to_string(rendered) do
    Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()
  end

  describe "new/3" do
    setup do
      author = insert(:author)
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, authors: [author])

      blueprint =
        insert(:section,
          base_project: project,
          type: :blueprint,
          title: "Test Blueprint",
          slug: "test-blueprint",
          open_and_free: false
        )

      section_1 =
        insert(:section,
          base_project: project,
          title: "Test Section 1",
          slug: "test-section-1",
          open_and_free: true,
          requires_payment: false,
          institution: institution,
          start_date: ~U[2024-01-01 00:00:00Z],
          end_date: ~U[2024-12-31 23:59:59Z],
          status: :active
        )

      section_2 =
        insert(:section,
          base_project: project,
          title: "Test Section 2",
          slug: "test-section-2",
          open_and_free: false,
          requires_payment: true,
          amount: Money.new(5000, "USD"),
          institution: institution,
          start_date: ~U[2024-02-01 00:00:00Z],
          end_date: ~U[2024-11-30 23:59:59Z],
          status: :deleted,
          blueprint_id: blueprint.id,
          blueprint: blueprint
        )

      instructor_1 = insert(:user, name: "John Doe")
      instructor_2 = insert(:user, name: "Jane Smith")

      Sections.enroll(instructor_1.id, section_1.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      Sections.enroll(instructor_2.id, section_1.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      ctx = %SessionContext{
        browser_timezone: "America/New_York",
        local_tz: "America/New_York",
        author: author,
        user: user,
        is_liveview: false,
        section: nil
      }

      sections = [section_1, section_2]

      %{
        ctx: ctx,
        sections: sections,
        section_1: section_1,
        section_2: section_2,
        institution: institution,
        project: project,
        blueprint: blueprint,
        instructor_1: instructor_1,
        instructor_2: instructor_2
      }
    end

    test "creates table model with default columns", %{ctx: ctx, sections: sections} do
      {:ok, model} = SectionsTableModel.new(ctx, sections)

      assert length(model.column_specs) == 11
      assert model.rows == Enum.sort_by(sections, & &1.start_date, :desc)
      assert model.event_suffix == ""
      assert model.id_field == [:id]

      column_names = Enum.map(model.column_specs, & &1.name)
      assert :title in column_names
      assert :tags in column_names
      assert :enrollments_count in column_names
      assert :requires_payment in column_names
      assert :start_date in column_names
      assert :end_date in column_names
      assert :base in column_names
      assert :instructor in column_names
      assert :institution in column_names
      assert :type in column_names
      assert :status in column_names
    end

    test "creates table model with custom options", %{ctx: ctx, sections: sections} do
      {:ok, model} =
        SectionsTableModel.new(ctx, sections,
          render_institution_action: true,
          exclude_columns: []
        )

      assert length(model.column_specs) == 11
      column_names = Enum.map(model.column_specs, & &1.name)
      assert :tags in column_names
      assert :instructor in column_names
      assert model.data.render_institution_action == true
      assert model.data.fade_data == true
    end

    test "creates table model with only required options", %{ctx: ctx, sections: sections} do
      {:ok, model} = SectionsTableModel.new(ctx, sections, [])

      assert length(model.column_specs) == 11
      assert model.data.render_institution_action == false
      assert model.data.fade_data == true
    end
  end

  describe "custom_render/3" do
    setup do
      author = insert(:author)
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, authors: [author])

      blueprint =
        insert(:section,
          base_project: project,
          type: :blueprint,
          title: "Test Blueprint",
          slug: "test-blueprint"
        )

      section =
        insert(:section,
          base_project: project,
          title: "Test Section",
          slug: "test-section",
          open_and_free: true,
          requires_payment: true,
          amount: Money.new(2500, "USD"),
          institution: institution,
          start_date: ~U[2024-01-01 00:00:00Z],
          end_date: ~U[2024-12-31 23:59:59Z],
          status: :active
        )

      instructor = insert(:user, name: "Test Instructor")

      Sections.enroll(instructor.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      ctx = %SessionContext{
        browser_timezone: "America/New_York",
        local_tz: "America/New_York",
        author: author,
        user: user,
        is_liveview: false,
        section: nil
      }

      assigns = %{ctx: ctx, render_institution_action: false}

      %{
        assigns: assigns,
        section: section,
        institution: institution,
        project: project,
        blueprint: blueprint,
        instructor: instructor
      }
    end

    test "renders title column", %{assigns: assigns, section: section} do
      column_spec = %ColumnSpec{name: :title}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ section.title
      assert rendered_str =~ section.slug
      assert rendered_str =~ "/sections/#{section.slug}/manage"
    end

    test "renders tags column", %{assigns: assigns, section: section} do
      column_spec = %ColumnSpec{name: :tags}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      
      # The tags column returns a Phoenix.LiveView.Rendered struct with a live_component
      # We can't serialize it to string outside LiveView context, so verify the structure
      assert match?(%Phoenix.LiveView.Rendered{}, rendered)
      assert rendered.static == ["<div>\n  ", "\n</div>"]
      assert is_function(rendered.dynamic, 1)
    end

    test "renders delivery column for open and free section", %{
      assigns: assigns,
      section: section
    } do
      column_spec = %ColumnSpec{name: :type}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "DD"
      assert rendered_str =~ "bg-Fill-Accent-fill-accent-purple"
      assert rendered_str =~ "text-Text-text-accent-purple"
    end

    test "renders delivery column for LTI section", %{assigns: assigns, section: section} do
      section = %{section | open_and_free: false}
      column_spec = %ColumnSpec{name: :type}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "LTI"
      assert rendered_str =~ "bg-Fill-Accent-fill-accent-teal"
      assert rendered_str =~ "text-Text-text-accent-teal"
    end

    test "renders requires_payment column for paid section", %{assigns: assigns, section: section} do
      column_spec = %ColumnSpec{name: :requires_payment}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "$2,500.00"
    end

    test "renders requires_payment column for free section", %{assigns: assigns, section: section} do
      section = %{section | requires_payment: false}
      column_spec = %ColumnSpec{name: :requires_payment}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str == "None"
    end

    test "renders requires_payment column with fallback", %{assigns: assigns, section: section} do
      section_with_invalid_amount = %{
        section
        | amount: %Money{amount: 0, currency: :invalid_currency},
          requires_payment: true
      }

      column_spec = %ColumnSpec{name: :requires_payment}

      rendered =
        SectionsTableModel.custom_render(assigns, section_with_invalid_amount, column_spec)

      rendered_str = rendered_to_string(rendered)

      assert rendered_str == "Yes"
    end

    test "renders institution column without action", %{
      assigns: assigns,
      section: section,
      institution: institution
    } do
      column_spec = %ColumnSpec{name: :institution}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ institution.name
      refute rendered_str =~ "Edit"
    end

    test "renders institution column with action", %{
      assigns: assigns,
      section: section,
      institution: institution
    } do
      assigns = %{assigns | render_institution_action: true}
      column_spec = %ColumnSpec{name: :institution}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ institution.name
      assert rendered_str =~ "Edit"
      assert rendered_str =~ "phx-click=\"edit_section\""
    end

    test "renders institution column without institution", %{assigns: assigns, section: section} do
      section = %{section | institution: nil}
      column_spec = %ColumnSpec{name: :institution}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "flex space-x-2 items-center"
      refute rendered_str =~ "Edit"
    end

    test "renders status column for active section", %{assigns: assigns, section: section} do
      column_spec = %ColumnSpec{name: :status}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "Active"
      assert rendered_str =~ "text-Table-text-accent-green"
    end

    test "renders status column for deleted section", %{assigns: assigns, section: section} do
      section = %{section | status: :deleted}
      column_spec = %ColumnSpec{name: :status}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "Deleted"
      assert rendered_str =~ "text-Table-text-danger"
    end

    test "renders base column for project-based section", %{
      assigns: assigns,
      section: section,
      project: project
    } do
      column_spec = %ColumnSpec{name: :base}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ project.title
      assert rendered_str =~ project.slug
      assert rendered_str =~ "/workspaces/course_author/#{project.slug}/overview"
    end

    test "renders base column for blueprint-based section", %{
      assigns: assigns,
      section: section,
      blueprint: blueprint
    } do
      section = %{section | blueprint_id: blueprint.id, blueprint: blueprint}
      column_spec = %ColumnSpec{name: :base}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ blueprint.title
      assert rendered_str =~ blueprint.slug
      assert rendered_str =~ "/products/#{blueprint.slug}"
    end

    test "renders instructor column", %{
      assigns: assigns,
      section: section,
      instructor: instructor
    } do
      column_spec = %ColumnSpec{name: :instructor}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ instructor.name
      assert rendered_str =~ "/admin/users/#{instructor.id}"
    end

    test "renders instructor column with linked author", %{
      assigns: assigns,
      section: section,
      instructor: instructor
    } do
      author = insert(:author)
      instructor_changeset = Ecto.Changeset.change(instructor, author_id: author.id)
      _updated_instructor = Oli.Repo.update!(instructor_changeset)

      column_spec = %ColumnSpec{name: :instructor}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ instructor.name
      assert rendered_str =~ "/admin/users/#{instructor.id}"
    end

    test "renders instructor column with multiple instructors", %{
      assigns: assigns,
      section: section
    } do
      instructor_1 = insert(:user, name: "John Doe")
      instructor_2 = insert(:user, name: "Jane Smith")

      Sections.enroll(instructor_1.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      Sections.enroll(instructor_2.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      column_spec = %ColumnSpec{name: :instructor}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "John Doe"
      assert rendered_str =~ "Jane Smith"
      assert rendered_str =~ ","
    end

    test "renders start_date column", %{assigns: assigns, section: section} do
      column_spec = %ColumnSpec{name: :start_date}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "December"
      assert rendered_str =~ "2023"
    end

    test "renders end_date column", %{assigns: assigns, section: section} do
      column_spec = %ColumnSpec{name: :end_date}
      rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
      rendered_str = rendered_to_string(rendered)

      assert rendered_str =~ "December"
      assert rendered_str =~ "2024"
    end
  end

  describe "format_date/3" do
    setup do
      author = insert(:author)
      user = insert(:user)

      ctx = %SessionContext{
        browser_timezone: "America/New_York",
        local_tz: "America/New_York",
        author: author,
        user: user,
        is_liveview: false,
        section: nil
      }

      section =
        insert(:section,
          start_date: ~U[2024-01-15 10:30:00Z],
          end_date: ~U[2024-12-15 15:45:00Z]
        )

      %{ctx: ctx, section: section}
    end

    test "formats date with timezone conversion", %{ctx: ctx, section: section} do
      assigns = %{ctx: ctx}

      start_rendered =
        SectionsTableModel.custom_render(assigns, section, %ColumnSpec{name: :start_date})

      assert rendered_to_string(start_rendered) =~ "January 15, 2024 05:30 AM"

      end_rendered =
        SectionsTableModel.custom_render(assigns, section, %ColumnSpec{name: :end_date})

      assert rendered_to_string(end_rendered) =~ "December 15, 2024"
    end
  end

  describe "render/1" do
    test "returns default render" do
      assigns = %{}
      rendered = SectionsTableModel.render(assigns)

      assert rendered_to_string(rendered) =~ "nothing"
    end
  end

  describe "table model integration" do
    setup do
      author = insert(:author)
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, authors: [author])

      section =
        insert(:section,
          base_project: project,
          title: "Integration Test Section",
          slug: "integration-test",
          open_and_free: true,
          requires_payment: false,
          institution: institution,
          status: :active,
          start_date: ~U[2024-01-01 00:00:00Z],
          end_date: ~U[2024-12-31 23:59:59Z]
        )

      ctx = %SessionContext{
        browser_timezone: "America/New_York",
        local_tz: "America/New_York",
        author: author,
        user: user,
        is_liveview: false,
        section: nil
      }

      %{ctx: ctx, section: section}
    end

    test "creates complete table model and renders all columns", %{ctx: ctx, section: section} do
      {:ok, model} = SectionsTableModel.new(ctx, [section])

      assert model.rows == [section]
      assert length(model.column_specs) == 11
      assert model.data.ctx == ctx

      Enum.each(model.column_specs, fn column_spec ->
        cond do
          column_spec.name in [:enrollments_count] ->
            # Skip enrollments_count as it's handled separately
            :ok
          column_spec.name == :tags ->
            # Tags column returns a LiveComponent that cannot be serialized to string
            assigns = %{ctx: ctx, render_institution_action: false}
            rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
            assert match?(%Phoenix.LiveView.Rendered{}, rendered)
          true ->
            assigns = %{ctx: ctx, render_institution_action: false}
            rendered = SectionsTableModel.custom_render(assigns, section, column_spec)
            rendered_str = rendered_to_string(rendered)
            assert is_binary(rendered_str)
        end
      end)
    end

    test "handles empty sections list", %{ctx: ctx} do
      {:ok, model} = SectionsTableModel.new(ctx, [])

      assert model.rows == []
      assert length(model.column_specs) == 11
    end

    test "handles sections with missing optional fields", %{ctx: ctx} do
      project = insert(:project)

      minimal_section =
        insert(:section,
          base_project: project,
          title: "Minimal Section",
          slug: "minimal-section",
          open_and_free: true,
          requires_payment: false,
          start_date: ~U[2024-01-01 00:00:00Z],
          end_date: ~U[2024-12-31 23:59:59Z]
        )

      {:ok, model} = SectionsTableModel.new(ctx, [minimal_section])

      assert length(model.rows) == 1
      assert length(model.column_specs) == 11

      Enum.each(model.column_specs, fn column_spec ->
        cond do
          column_spec.name in [:enrollments_count] ->
            # Skip enrollments_count as it's handled separately
            :ok
          column_spec.name == :tags ->
            # Tags column returns a LiveComponent that cannot be serialized to string
            assigns = %{ctx: ctx, render_institution_action: false}
            rendered = SectionsTableModel.custom_render(assigns, minimal_section, column_spec)
            assert match?(%Phoenix.LiveView.Rendered{}, rendered)
          true ->
            assigns = %{ctx: ctx, render_institution_action: false}
            rendered = SectionsTableModel.custom_render(assigns, minimal_section, column_spec)
            rendered_str = rendered_to_string(rendered)
            assert is_binary(rendered_str)
        end
      end)
    end
  end
end
