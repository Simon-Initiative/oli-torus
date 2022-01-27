defmodule Oli.Delivery.Sections.BrowseTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions}
  alias Oli.Institutions.Institution
  alias Lti_1p3.Tool.ContextRoles
  import Ecto.Query, warn: false

  def browse(offset, field, direction, text_search) do
    Browse.browse_sections(
      %Paging{offset: offset, limit: 3},
      %Sorting{field: field, direction: direction},
      %BrowseOptions{
        show_deleted: false,
        institution_id: nil,
        blueprint_id: nil,
        active_only: false,
        text_search: text_search
      }
    )
  end

  # For each section, enroll a different number of students. First section gets 1,
  # section gets 2, then third gets 3, etc
  def enroll(sections) do
    map =
      Enum.map(1..32, fn _ -> user_fixture() end)
      |> Enum.map(fn u -> u.id end)
      |> Enum.with_index(fn u, i -> {i, u} end)
      |> Enum.reduce(%{}, fn {i, id}, m -> Map.put(m, i, id) end)

    Enum.with_index(sections, fn s, i ->
      Enum.each(1..(i + 1), fn i ->
        Sections.enroll(Map.get(map, i), s.id, [ContextRoles.get_role(:context_learner)])
      end)
    end)

    sections
  end

  describe "basic browsing" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, institution2} =
        Institution.changeset(%Institution{}, %{
          name: "ZZZ",
          country_code: "US",
          institution_email: "noone",
          institution_url: "example.edu",
          timezone: "America/New_York"
        })
        |> Repo.insert()

      sections =
        (make_sections(map.project, map.institution, "a", 10, %{}) ++
           make_sections(map.project, institution2, "b", 10, %{}) ++
           make_sections(map.project, nil, "c", 10, %{}))
        |> enroll

      # There is only one section that is "active" in that the start and end dates overlap today
      Sections.update_section(hd(sections), %{start_date: yesterday(), end_date: tomorrow()})

      Sections.update_section(Enum.at(sections, 1), %{
        start_date: yesterday(),
        end_date: yesterday(),
        blueprint_id: hd(sections).id
      })

      Sections.update_section(Enum.at(sections, 2), %{
        start_date: tomorrow(),
        end_date: tomorrow()
      })

      # Finally, add one section that is deleted
      make(map.project, map.institution, "DELETED", %{status: :deleted})

      Map.put(map, :sections, sections) |> Map.put(:second, institution2)
    end

    test "basic sorting", %{second: second, sections: sections} do
      # Verify that sorting works:
      results = browse(0, :title, :asc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 30
      assert hd(results).title == "a-A"

      results = browse(0, :title, :desc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 30
      assert hd(results).title == "c-J"

      results = browse(0, :institution, :asc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 30
      assert hd(results).institution_name == "CMU"

      results = browse(12, :institution, :asc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 30
      assert hd(results).institution_name == "ZZZ"

      results = browse(0, :enrollments_count, :desc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 30
      assert hd(results).enrollments_count == 30

      results = browse(0, :enrollments_count, :asc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 30
      assert hd(results).enrollments_count == 1

      # Verify that text search works. There are three sections with J in the title
      results = browse(0, :title, :asc, "J")
      assert length(results) == 3
      assert hd(results).total_count == 3

      # Verify we can filter by institution
      results =
        Browse.browse_sections(
          %Paging{offset: 0, limit: 3},
          %Sorting{field: :title, direction: :asc},
          %BrowseOptions{
            show_deleted: false,
            institution_id: second.id,
            blueprint_id: nil,
            active_only: false,
            text_search: nil
          }
        )

      assert length(results) == 3
      assert hd(results).total_count == 10
      assert hd(results).institution_name == "ZZZ"

      # Verify that we can filter by institution AND do a text search. There is
      # exactly one section with H in the title and pinned to the second institution
      results =
        Browse.browse_sections(
          %Paging{offset: 0, limit: 3},
          %Sorting{field: :title, direction: :asc},
          %BrowseOptions{
            show_deleted: false,
            institution_id: second.id,
            blueprint_id: nil,
            active_only: false,
            text_search: "H"
          }
        )

      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).title == "b-H"

      # Verify that "active only" finds the one section with start and
      # end dates that overlap today
      results =
        Browse.browse_sections(
          %Paging{offset: 0, limit: 3},
          %Sorting{field: :title, direction: :asc},
          %BrowseOptions{
            show_deleted: false,
            institution_id: nil,
            blueprint_id: nil,
            active_only: true,
            text_search: nil
          }
        )

      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).title == "a-A"

      # Verify that "show deleted" works
      results =
        Browse.browse_sections(
          %Paging{offset: 0, limit: 3},
          %Sorting{field: :title, direction: :asc},
          %BrowseOptions{
            show_deleted: true,
            institution_id: nil,
            blueprint_id: nil,
            active_only: false,
            text_search: nil
          }
        )

      assert length(results) == 3
      assert hd(results).total_count == 31

      # Verify we can filter by blueprint
      results =
        Browse.browse_sections(
          %Paging{offset: 0, limit: 3},
          %Sorting{field: :title, direction: :asc},
          %BrowseOptions{
            show_deleted: false,
            institution_id: nil,
            blueprint_id: hd(sections).id,
            active_only: false,
            text_search: nil
          }
        )

      assert length(results) == 1
      assert hd(results).total_count == 1
    end
  end
end
