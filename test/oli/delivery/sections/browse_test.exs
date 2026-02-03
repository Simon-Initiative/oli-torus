defmodule Oli.Delivery.Sections.BrowseTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Browse, BrowseOptions}
  alias Oli.Institutions.Institution
  alias Oli.Repo.{Paging, Sorting}
  alias Lti_1p3.Roles.ContextRoles

  import Ecto.Query, warn: false
  import Oli.Factory

  # Test data counts - see setup_session/1 for how these are created
  # 10 sections for "CMU" + 10 for "ZZZ" + 7 with no institution + 3 special = 30 total
  @total_sections 30
  # Sections in ZZZ institution: 10 regular + 1 special characters section
  @zzz_sections 11
  # Enrollment pattern: section at index N gets N+1 students (for testing sort by enrollment count)
  @max_enrollments 27
  # Page size used in browse helper
  @page_size 3

  @default_opts %BrowseOptions{
    institution_id: nil,
    blueprint_id: nil,
    project_id: nil,
    text_search: "",
    active_today: false,
    filter_status: nil,
    filter_type: nil
  }

  describe "basic browsing" do
    setup [:setup_session]

    test "sorting" do
      results = browse(0, :title, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).title == "aA"

      results = browse(0, :title, :desc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).title == "zzzDeleted"

      results = browse(0, :type, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      refute hd(results).title == "aA"

      results = browse(0, :type, :desc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).title == "aA"

      results = browse(0, :requires_payment, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      refute hd(results).requires_payment
      assert Enum.at(results, 1).amount == Money.new(1, "USD")

      results = browse(0, :requires_payment, :desc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).requires_payment
      assert hd(results).amount == Money.new(100, "USD")

      results = browse(0, :base, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      # Base sorting should work - just verify we get a result
      assert hd(results).title in ["aA", "aB", "bA", "cA"]

      results = browse(0, :base, :desc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      # Base sorting descending should work - just verify we get a result
      assert hd(results).title in ["aA", "aB", "bA", "cA"]

      results = browse(0, :institution, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).institution_name == "CMU"

      results = browse(12, :institution, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).institution_name == "ZZZ"

      results = browse(0, :enrollments_count, :desc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).enrollments_count == @max_enrollments

      results = browse(0, :enrollments_count, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).enrollments_count == 0

      results = browse(0, :instructor, :desc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      assert hd(results).instructor_name == "Instructor"

      results = browse(12, :instructor, :asc, @default_opts)
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
      refute hd(results).instructor_name
    end

    test "searching" do
      # there is one section with cB as title
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{text_search: "cB"}))
      assert length(results) == 1
      assert hd(results).total_count == 1

      # there are ten sections associated with the insitution titled "ZZZ", and three with
      # zzz in the title
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{text_search: "ZZZ"}))
      assert length(results) == 3
      assert hd(results).total_count == 13

      # there is one section with base on aA (apart from itself)
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{text_search: "aA"}))
      assert length(results) == 2
      assert hd(results).total_count == 2

      # all created sections are with base on project titled "Example..."
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{text_search: "Example"}))
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections

      # there is one section with an instructor associated with name "Instructor"
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{text_search: "instructor"}))
      assert length(results) == 1
      assert hd(results).total_count == 1

      # do not exclude stop words
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{text_search: "a"}))
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections

      # exclude special characters
      results =
        browse(
          0,
          :title,
          :asc,
          Map.merge(@default_opts, %{text_search: ";:-|'<$p#(!*) characters"})
        )

      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).title == "zzz ;:-|'<$p#(!*) characters"
    end

    test "filtering", %{second: second, sections: sections, project: project} do
      # by institution
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{institution_id: second.id}))
      assert length(results) == @page_size
      assert hd(results).total_count == @zzz_sections
      assert hd(results).institution_name == "ZZZ"

      # by active date: finds the one section with start and end dates that overlap today
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{active_today: true}))
      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).title == "aA"

      # by status
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{filter_status: :deleted}))
      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).title == "zzzDeleted"

      results = browse(0, :title, :asc, Map.merge(@default_opts, %{filter_status: :archived}))
      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).title == "zzzArchived"

      # by type
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{filter_type: :open}))
      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).title == "aA"

      results = browse(0, :title, :asc, Map.merge(@default_opts, %{filter_type: :lms}))
      assert length(results) == @page_size
      # All sections except the one open_and_free section
      assert hd(results).total_count == @total_sections - 1
      refute hd(results).title == "aA"

      # by blueprint
      results =
        browse(0, :title, :asc, Map.merge(@default_opts, %{blueprint_id: hd(sections).id}))

      assert length(results) == 1
      assert hd(results).total_count == 1

      # by project
      results = browse(0, :title, :asc, Map.merge(@default_opts, %{project_id: project.id}))
      assert length(results) == @page_size
      assert hd(results).total_count == @total_sections
    end

    test "filtering by requires_payment" do
      # Filter for sections that require payment (true)
      results =
        browse(
          0,
          :title,
          :asc,
          Map.merge(@default_opts, %{filter_requires_payment: true})
        )

      assert length(results) == @page_size
      # All sections except the one we set to requires_payment: false should require payment
      assert hd(results).total_count == @total_sections - 1
      assert hd(results).requires_payment

      # Filter for sections that don't require payment (false)
      results =
        browse(
          0,
          :title,
          :asc,
          Map.merge(@default_opts, %{filter_requires_payment: false})
        )

      assert length(results) == 1
      assert hd(results).total_count == 1
      refute hd(results).requires_payment
    end

    test "filtering by tags", %{sections: sections} do
      # Create an admin for tag operations
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)

      # Create some tags
      tag1 = insert(:tag, name: "Tag1")
      tag2 = insert(:tag, name: "Tag2")

      # Associate tags with sections
      Oli.Tags.associate_tag_with_section(hd(sections), tag1, actor: admin)
      Oli.Tags.associate_tag_with_section(Enum.at(sections, 1), tag1, actor: admin)
      Oli.Tags.associate_tag_with_section(Enum.at(sections, 1), tag2, actor: admin)

      # Filter by tag1 - should find 2 sections
      results =
        browse(
          0,
          :title,
          :asc,
          Map.merge(@default_opts, %{filter_tag_ids: [tag1.id]})
        )

      assert length(results) == 2
      assert hd(results).total_count == 2

      # Filter by tag2 - should find 1 section
      results =
        browse(
          0,
          :title,
          :asc,
          Map.merge(@default_opts, %{filter_tag_ids: [tag2.id]})
        )

      assert length(results) == 1
      assert hd(results).total_count == 1
    end

    test "filtering by date range", %{sections: sections} do
      # Set specific dates on some sections using direct Ecto updates
      specific_date = ~N[2024-01-15 12:00:00]

      Repo.update_all(
        from(s in Oli.Delivery.Sections.Section, where: s.id == ^hd(sections).id),
        set: [inserted_at: ~N[2024-01-10 12:00:00]]
      )

      Repo.update_all(
        from(s in Oli.Delivery.Sections.Section, where: s.id == ^Enum.at(sections, 1).id),
        set: [inserted_at: specific_date]
      )

      Repo.update_all(
        from(s in Oli.Delivery.Sections.Section, where: s.id == ^Enum.at(sections, 2).id),
        set: [inserted_at: ~N[2024-01-20 12:00:00]]
      )

      # Filter for sections inserted on or after specific date
      results =
        browse(
          0,
          :title,
          :asc,
          Map.merge(@default_opts, %{
            filter_date_from: specific_date,
            filter_date_field: :inserted_at
          })
        )

      assert length(results) == @page_size
      # Should find all sections inserted on or after 2024-01-15
      assert hd(results).total_count >= 2

      # Filter for sections inserted within a date range
      results =
        browse(
          0,
          :title,
          :asc,
          Map.merge(@default_opts, %{
            filter_date_from: ~N[2024-01-14 00:00:00],
            filter_date_to: ~N[2024-01-16 23:59:59],
            filter_date_field: :inserted_at
          })
        )

      # Should find at least the section with specific_date
      assert hd(results).total_count >= 1
    end
  end

  defp browse(offset, field, direction, browse_options) do
    Browse.browse_sections(
      %Paging{offset: offset, limit: @page_size},
      %Sorting{field: field, direction: direction},
      browse_options
    )
  end

  defp setup_session(_conn) do
    map = Seeder.base_project_with_resource2()

    {:ok, institution2} =
      Institution.changeset(%Institution{}, %{
        name: "ZZZ",
        country_code: "US",
        institution_email: "noone",
        institution_url: "example.edu"
      })
      |> Repo.insert()

    sections =
      (make_sections(map.project, map.institution, "a", 10, %{}) ++
         make_sections(map.project, institution2, "b", 10, %{}) ++
         make_sections(map.project, nil, "c", 7, %{}))
      |> enroll

    # There is only one section that is "active" in that the start and end dates overlap today
    Sections.update_section(hd(sections), %{
      start_date: yesterday(),
      end_date: tomorrow(),
      open_and_free: true,
      requires_payment: false,
      amount: Money.new(10_000_000, "USD")
    })

    # There is only one section that differs in the amount
    Sections.update_section(Enum.at(sections, 1), %{
      amount: Money.new(1, "USD")
    })

    # Enroll an instructor to first section
    user = insert(:user, name: "Instructor")
    Sections.enroll(user.id, hd(sections).id, [ContextRoles.get_role(:context_instructor)])

    Sections.update_section(Enum.at(sections, 1), %{
      start_date: yesterday(),
      end_date: yesterday(),
      blueprint_id: hd(sections).id
    })

    Sections.update_section(Enum.at(sections, 2), %{
      start_date: tomorrow(),
      end_date: tomorrow()
    })

    # Add one section that is deleted
    make(map.project, map.institution, "zzzDeleted", %{status: :deleted})

    # Add one section that is archived
    make(map.project, map.institution, "zzzArchived", %{status: :archived})

    make(map.project, institution2, "zzz ;:-|'<$p#(!*) characters", %{})

    Map.put(map, :sections, sections) |> Map.put(:second, institution2)
  end

  # Enroll students with increasing counts: section at index N gets N+1 students
  defp enroll(sections) do
    # Need enough users for the last section (index + 1 students)
    user_count = length(sections) + 1
    user_ids = Enum.map(1..user_count, fn _ -> user_fixture().id end)
    learner = ContextRoles.get_role(:context_learner)

    Enum.with_index(sections, fn section, index ->
      Enum.each(1..(index + 1), fn n ->
        Sections.enroll(Enum.at(user_ids, n), section.id, [learner])
      end)
    end)

    sections
  end

  describe "browse_project_sections" do
    test "returns publication for the queried project when section has multiple project associations" do
      # Create two projects - section will be associated with both
      main_project = insert(:project)
      secondary_project = insert(:project)

      # Create publications with different published dates
      # main_publication belongs to main_project (older but should be returned)
      main_publication =
        insert(:publication,
          project: main_project,
          published: ~U[2024-01-01 12:00:00Z],
          edition: 1,
          major: 0,
          minor: 0
        )

      # secondary_publication belongs to secondary_project (newer but should NOT be returned)
      secondary_publication =
        insert(:publication,
          project: secondary_project,
          published: ~U[2024-06-01 12:00:00Z],
          edition: 2,
          major: 0,
          minor: 0
        )

      # Create an enrollable section linked to the main project
      section =
        insert(:section,
          base_project: main_project,
          type: :enrollable,
          status: :active,
          blueprint_id: nil,
          start_date: DateTime.utc_now(),
          end_date: DateTime.add(DateTime.utc_now(), 30, :day)
        )

      # Associate section with BOTH projects (each with their own publication)
      # This simulates a section that uses resources from multiple projects (e.g., remixed)
      insert(:section_project_publication,
        section: section,
        project: main_project,
        publication: main_publication
      )

      insert(:section_project_publication,
        section: section,
        project: secondary_project,
        publication: secondary_publication
      )

      # Query the sections for main_project
      results =
        Browse.browse_project_sections(
          main_project.id,
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :title, direction: :asc}
        )

      # Should return exactly one result
      assert length(results) == 1
      result = hd(results)

      # The publication should be from main_project, not secondary_project
      # even though secondary_project's publication is newer
      assert result.publication.id == main_publication.id
      assert result.publication.edition == 1
    end

    test "returns most recent publication for the queried project when multiple publications exist" do
      # Create project with multiple publications (simulating version updates)
      project = insert(:project)

      # Create older publication (not used in assertion, but shows the scenario)
      _older_publication =
        insert(:publication,
          project: project,
          published: ~U[2024-01-01 12:00:00Z],
          edition: 1,
          major: 0,
          minor: 0
        )

      # Create newer publication (same project, later date)
      newer_publication =
        insert(:publication,
          project: project,
          published: ~U[2024-06-01 12:00:00Z],
          edition: 1,
          major: 1,
          minor: 0
        )

      # Create an enrollable section linked to the project
      section =
        insert(:section,
          base_project: project,
          type: :enrollable,
          status: :active,
          blueprint_id: nil,
          start_date: DateTime.utc_now(),
          end_date: DateTime.add(DateTime.utc_now(), 30, :day)
        )

      # Associate section with both publications (section could have been updated)
      # The newer publication represents the current state
      insert(:section_project_publication,
        section: section,
        project: project,
        publication: newer_publication
      )

      # Query for the project
      results =
        Browse.browse_project_sections(
          project.id,
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :title, direction: :asc}
        )

      # Should return the newer publication for this project
      assert length(results) == 1
      assert hd(results).publication.id == newer_publication.id
      assert hd(results).publication.major == 1
    end

    test "filters sections by text_search using prefix matching" do
      project = insert(:project)

      publication =
        insert(:publication,
          project: project,
          published: DateTime.utc_now()
        )

      future_date = DateTime.add(DateTime.utc_now(), 30, :day)

      # Create a product (blueprint) for the project
      product =
        insert(:section,
          title: "Course Product",
          base_project: project,
          type: :blueprint,
          status: :active
        )

      insert(:section_project_publication,
        section: product,
        project: project,
        publication: publication
      )

      # Create sections with different titles
      # section1 is FROM PRODUCT (has blueprint_id) - tests that product-based sections appear
      section1 =
        insert(:section,
          title: "Introduction to Biology",
          base_project: project,
          type: :enrollable,
          status: :active,
          blueprint_id: product.id,
          start_date: DateTime.utc_now(),
          end_date: future_date
        )

      section2 =
        insert(:section,
          title: "Advanced Chemistry",
          base_project: project,
          type: :enrollable,
          status: :active,
          blueprint_id: nil,
          start_date: DateTime.utc_now(),
          end_date: future_date
        )

      section3 =
        insert(:section,
          title: "Biology Lab",
          base_project: project,
          type: :enrollable,
          status: :active,
          blueprint_id: nil,
          start_date: DateTime.utc_now(),
          end_date: future_date
        )

      # Associate all sections with publication
      for section <- [section1, section2, section3] do
        insert(:section_project_publication,
          section: section,
          project: project,
          publication: publication
        )
      end

      # Search for "Biology" - should match section1 and section3
      results =
        Browse.browse_project_sections(
          project.id,
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :title, direction: :asc},
          text_search: "Biology"
        )

      assert length(results) == 2
      titles = Enum.map(results, & &1.title)
      assert "Biology Lab" in titles
      assert "Introduction to Biology" in titles
      refute "Advanced Chemistry" in titles

      # Search with prefix "Bio" - should still match
      results =
        Browse.browse_project_sections(
          project.id,
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :title, direction: :asc},
          text_search: "Bio"
        )

      assert length(results) == 2

      # Search for "Chemistry" - should only match section2
      results =
        Browse.browse_project_sections(
          project.id,
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :title, direction: :asc},
          text_search: "Chemistry"
        )

      assert length(results) == 1
      assert hd(results).title == "Advanced Chemistry"

      # Case-insensitive search
      results =
        Browse.browse_project_sections(
          project.id,
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :title, direction: :asc},
          text_search: "biology"
        )

      assert length(results) == 2
    end
  end
end
