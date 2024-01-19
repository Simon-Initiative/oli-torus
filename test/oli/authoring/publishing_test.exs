defmodule Oli.Authoring.PublishingTest do
  use Oli.DataCase
  import Oli.Factory

  alias Oli.Authoring.Publishing

  describe "find_instructors_enrolled_in/1" do
    test "searches for enrolled instructors only" do
      instructor_1 = insert(:user, can_create_sections: true)
      instructor_2 = insert(:user, can_create_sections: true)
      student = insert(:user, can_create_sections: false)

      section = insert(:section)

      # Order is important here
      insert(:enrollment, section: section, user: instructor_1)
      insert(:enrollment, section: section, user: student)
      insert(:enrollment, section: section, user: instructor_2)

      instructor_ids = Publishing.find_instructors_enrolled_in(section) |> Enum.map(& &1.id)

      assert instructor_1.id in instructor_ids
      assert instructor_2.id in instructor_ids
      refute student.id in instructor_ids

      # Testing order_by
      assert [instructor_1.id, instructor_2.id] == instructor_ids
    end
  end

  describe "find_oldest_enrolled_instructor/1" do
    test "searches for the oldest user enrolled in a section -- the creator" do
      instructor_1 = insert(:user, can_create_sections: true)
      instructor_2 = insert(:user, can_create_sections: true)

      section = insert(:section)

      # Order is important here
      insert(:enrollment, section: section, user: instructor_1)
      insert(:enrollment, section: section, user: instructor_2)

      oldest_user = Publishing.find_oldest_enrolled_instructor(section)

      assert instructor_1.id == oldest_user.id
    end
  end
end
