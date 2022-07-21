defmodule Oli.Delivery.Attempts.BrowseUpdatesTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, GradeUpdateBrowseOptions}

  defp resource_access_fixture(attrs) do
    %ResourceAccess{}
    |> ResourceAccess.changeset(attrs)
    |> Repo.insert()
  end

  defp lms_grade_update_fixture(attrs) do
    Attempts.create_lms_grade_update(attrs)
  end

  def browse(section, user_id, offset, field, direction, text_search) do
    Attempts.browse_lms_grade_updates(
      %Paging{offset: offset, limit: 3},
      %Sorting{field: field, direction: direction},
      %GradeUpdateBrowseOptions{
        section_id: section.id,
        user_id: user_id,
        text_search: text_search
      }
    )
  end

  describe "creating the attempt tree records" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.create_section_resources()
    end

    test "create the attempt tree", %{
      section: section,
      user1: user1,
      user2: user2,
      page1: page
    } do
      {:ok, ra1} =
        resource_access_fixture(%{
          section_id: section.id,
          user_id: user1.id,
          resource_id: page.id,
          access_count: 1,
          score: 1.0,
          out_of: 1.0
        })

      {:ok, ra2} =
        resource_access_fixture(%{
          section_id: section.id,
          user_id: user2.id,
          resource_id: page.id,
          access_count: 1,
          score: 1.0,
          out_of: 1.0
        })

      Enum.each(1..5, fn n ->
        lms_grade_update_fixture(%{
          resource_access_id: ra1.id,
          score: 0.0,
          out_of: 1.0,
          type: :inline,
          result: :failure,
          attempt_number: n
        })
      end)

      Enum.each(1..3, fn n ->
        lms_grade_update_fixture(%{
          resource_access_id: ra2.id,
          score: 1.0,
          out_of: 2.0,
          type: :manual,
          result: :success,
          attempt_number: n
        })
      end)

      # Verify we can access all records
      assert browse(section, nil, 0, :user_email, :asc, nil) |> Enum.count() == 3
      assert (browse(section, nil, 0, :user_email, :asc, nil) |> hd).total_count == 8

      # Verify filtering by user id works:
      assert browse(section, user1.id, 0, :user_email, :asc, nil) |> Enum.count() == 3
      assert (browse(section, user1.id, 0, :user_email, :asc, nil) |> hd).total_count == 5
      assert browse(section, user2.id, 0, :user_email, :asc, nil) |> Enum.count() == 3
      assert (browse(section, user2.id, 0, :user_email, :asc, nil) |> hd).total_count == 3

      # Verify filtering by text search works
      assert browse(section, nil, 0, :user_email, :asc, "failure") |> Enum.count() == 3
      assert (browse(section, nil, 0, :user_email, :asc, "failure") |> hd).total_count == 5

      # Verify sorting works
      assert (browse(section, nil, 0, :score, :asc, nil) |> hd).user_email == user1.email
      assert (browse(section, nil, 0, :score, :desc, nil) |> hd).user_email == user2.email
      assert (browse(section, nil, 0, :out_of, :asc, nil) |> hd).user_email == user1.email
      assert (browse(section, nil, 0, :out_of, :desc, nil) |> hd).user_email == user2.email
      assert (browse(section, nil, 0, :type, :asc, nil) |> hd).user_email == user1.email
      assert (browse(section, nil, 0, :type, :desc, nil) |> hd).user_email == user2.email
      assert (browse(section, nil, 0, :result, :asc, nil) |> hd).user_email == user1.email
      assert (browse(section, nil, 0, :result, :desc, nil) |> hd).user_email == user2.email
      assert (browse(section, nil, 0, :attempt_number, :asc, nil) |> hd).attempt_number == 1
      assert (browse(section, nil, 0, :attempt_number, :desc, nil) |> hd).attempt_number == 5
    end
  end
end
