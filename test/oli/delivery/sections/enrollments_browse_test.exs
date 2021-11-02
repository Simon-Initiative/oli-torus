defmodule Oli.Delivery.Sections.EnrollmentsBrowseTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias Lti_1p3.Tool.ContextRoles
  import Ecto.Query, warn: false

  def make_sections(project, institution, prefix, n, attrs) do
    65..(65 + (n - 1))
    |> Enum.map(fn value -> List.to_string([value]) end)
    |> Enum.map(fn value -> make(project, institution, "#{prefix}-#{value}", attrs) end)
  end

  def browse(section, offset, field, direction, text_search, is_student, is_instructor) do
    Sections.browse_enrollments(
      section,
      %Paging{offset: offset, limit: 3},
      %Sorting{field: field, direction: direction},
      %EnrollmentBrowseOptions{
        is_student: is_student,
        is_instructor: is_instructor,
        text_search: text_search
      }
    )
  end

  def make(project, institution, title, attrs) do
    {:ok, section} =
      Sections.create_section(
        Map.merge(
          %{
            title: title,
            timezone: "1",
            registration_open: true,
            context_id: UUID.uuid4(),
            institution_id:
              if is_nil(institution) do
                nil
              else
                institution.id
              end,
            base_project_id: project.id
          },
          attrs
        )
      )

    section
  end

  # Create and enroll 11 users, with 6 being students and 5 being instructors
  def enroll(section) do
    to_attrs = fn v ->
      %{
        sub: UUID.uuid4(),
        name: "#{v}",
        given_name: "#{v}",
        family_name: "#{v}",
        middle_name: "",
        picture: "https://platform.example.edu/jane.jpg",
        email: "test#{v}@example.edu",
        locale: "en-US"
      }
    end

    Enum.map(1..11, fn v -> to_attrs.(v) |> user_fixture() end)
    |> Enum.with_index(fn user, index ->
      roles =
        case rem(index, 2) do
          0 ->
            [ContextRoles.get_role(:context_learner)]

          _ ->
            [ContextRoles.get_role(:context_learner), ContextRoles.get_role(:context_instructor)]
        end

      # Between the first two enrollments, delay enough that we get distinctly different
      # enrollment times
      case index do
        1 -> :timer.sleep(1500)
        _ -> true
      end

      Sections.enroll(user.id, section.id, roles)
    end)
  end

  describe "basic browsing" do
    setup do
      map = Seeder.base_project_with_resource2()

      section1 = make(map.project, map.institution, "a", %{})
      section2 = make(map.project, map.institution, "b", %{})

      enroll(section1)

      Map.put(map, :section1, section1) |> Map.put(:section2, section2)
    end

    test "basic sorting", %{section1: section1, section2: section2} do
      # Verify that retrieving all users works
      results = browse(section1, 0, :name, :asc, nil, false, false)
      assert length(results) == 3
      assert hd(results).total_count == 11

      # Verify that retrieving only instructors works
      results = browse(section1, 0, :name, :asc, nil, false, true)
      assert length(results) == 3
      assert hd(results).total_count == 5

      # Verify that retrieving only students works
      results = browse(section1, 0, :name, :asc, nil, true, false)
      assert length(results) == 3
      assert hd(results).total_count == 6

      # Verify that retrieving only students works WITH text search
      results = browse(section1, 0, :name, :asc, "5", true, false)
      assert length(results) == 1
      assert hd(results).total_count == 1

      # Verify that sorting by enrollment_date works
      results = browse(section1, 0, :enrollment_date, :asc, nil, false, false)
      assert length(results) == 3
      assert hd(results).total_count == 11
      assert hd(results).name == "1"

      # Verify offset and reverse sort for enrollment_date
      results = browse(section1, 10, :enrollment_date, :desc, nil, false, false)
      assert length(results) == 1
      assert hd(results).total_count == 11
      assert hd(results).name == "1"

      # Verify that zero enrollments return for section2
      results = browse(section2, 00, :enrollment_date, :desc, nil, false, false)
      assert length(results) == 0
    end
  end
end
