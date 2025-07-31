defmodule Oli.Delivery.Sections.EnrollmentsBrowseTest do
  use Oli.DataCase

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias Lti_1p3.Roles.ContextRoles

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

  # Create and enroll 11 users, with 6 being students and 5 being instructors
  def enroll(section) do
    to_attrs = fn v ->
      %{
        sub: UUID.uuid4(),
        name: "#{v}",
        given_name: "#{v}",
        family_name: "name_#{v}",
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

      {:ok, enrollment} = Sections.enroll(user.id, section.id, roles)

      # Have the first enrolled student also have made a payment for this section
      case index do
        2 ->
          Oli.Delivery.Paywall.create_payment(%{
            type: :direct,
            generation_date: DateTime.utc_now(),
            application_date: DateTime.utc_now(),
            amount: Money.new(100, "USD"),
            provider_type: :stripe,
            provider_id: "1",
            provider_payload: %{},
            pending_user_id: user.id,
            pending_section_id: section.id,
            enrollment_id: enrollment.id,
            section_id: section.id
          })

        _ ->
          true
      end
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

      # Verify that sorting by payment_date works, in both directions
      results = browse(section1, 0, :payment_date, :asc, nil, false, false)
      assert length(results) == 3
      assert hd(results).total_count == 11
      assert hd(results).name == "3"
      refute is_nil(hd(results).payment_date)

      results = browse(section1, 10, :payment_date, :desc, nil, false, false)
      assert length(results) == 1
      assert hd(results).total_count == 11
      assert hd(results).name == "3"

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
