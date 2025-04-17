defmodule Oli.Accounts.UserBrowseTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Accounts
  alias Oli.Accounts.{UserBrowseOptions}
  alias Lti_1p3.Roles.ContextRoles
  import Ecto.Query, warn: false

  def browse(offset, field, direction, text_search, include) do
    Accounts.browse_users(
      %Paging{offset: offset, limit: 3},
      %Sorting{field: field, direction: direction},
      %UserBrowseOptions{
        include_guests: include,
        text_search: text_search
      }
    )
  end

  def make_section(project, institution, title, attrs) do
    {:ok, section} =
      Sections.create_section(
        Map.merge(
          %{
            title: title,
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

  def enroll(section, user) do
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
  end

  describe "basic browsing" do
    setup do
      map = Seeder.base_project_with_resource2()

      section = make_section(map.project, map.institution, "a", %{})
      section2 = make_section(map.project, map.institution, "a", %{})

      users =
        Enum.map(0..9, fn value ->
          user_fixture(%{guest: rem(value, 2) == 0, name: List.to_string([value + 65])})
        end)

      enroll(section, Enum.at(users, 3))
      enroll(section2, Enum.at(users, 3))
      enroll(section2, Enum.at(users, 4))

      map
    end

    test "basic browsing functionality", %{} do
      # Verify that sorting works:
      results = browse(0, :name, :asc, nil, true)
      assert length(results) == 3
      assert hd(results).total_count == 10
      assert hd(results).name == "A"

      results = browse(0, :name, :desc, nil, true)
      assert length(results) == 3
      assert hd(results).total_count == 10
      assert hd(results).name == "J"

      results = browse(0, :enrollments_count, :desc, nil, true)
      assert length(results) == 3
      assert hd(results).total_count == 10
      assert hd(results).name == "D"
      assert hd(results).enrollments_count == 2

      results = browse(0, :enrollments_count, :desc, "B", true)
      assert length(results) == 1
      assert hd(results).total_count == 1
      assert hd(results).name == "B"

      results = browse(0, :enrollments_count, :desc, nil, false)
      assert length(results) == 3
      assert hd(results).total_count == 5
    end
  end
end
