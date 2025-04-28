defmodule Oli.Delivery.Attempts.CanAccessTest do
  use Oli.DataCase
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.PageLifecycle

  def create_attempt(revision, student, section) do
    ra = Core.track_access(revision.resource_id, section.id, student.id)
    Core.update_resource_access(ra, %{score: 5, out_of: 10})

    Core.create_resource_attempt(%{
      attempt_guid: UUID.uuid4(),
      attempt_number: 1,
      content: %{},
      resource_access_id: ra.id,
      revision_id: revision.id,
      date_evaluated: DateTime.utc_now(),
      score: 5,
      out_of: 10
    })
  end

  describe "can_access_attempt" do
    setup do
      student1 = user_fixture()
      student2 = user_fixture()
      instructor1 = user_fixture()
      instructor2 = user_fixture()

      map = Seeder.base_project_with_resource4()
      revision = map.revision1
      section1 = map.section_1
      section2 = map.section_2

      Sections.enroll(student1.id, section1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student2.id, section1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor1.id, section1.id, [ContextRoles.get_role(:context_instructor)])

      Sections.enroll(student1.id, section2.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor2.id, section2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, resource_attempt1} = create_attempt(revision, student1, section1)
      {:ok, resource_attempt2} = create_attempt(revision, student2, section1)
      {:ok, resource_attempt3} = create_attempt(revision, student1, section2)

      {:ok,
       student1: student1,
       student2: student2,
       instructor1: instructor1,
       instructor2: instructor2,
       section1: section1,
       section2: section2,
       resource_attempt1: resource_attempt1,
       resource_attempt2: resource_attempt2,
       resource_attempt3: resource_attempt3}
    end

    test "", %{
      student1: student1,
      student2: student2,
      instructor1: instructor1,
      instructor2: instructor2,
      section1: section1,
      section2: section2,
      resource_attempt1: resource_attempt1,
      resource_attempt2: resource_attempt2,
      resource_attempt3: resource_attempt3
    } do
      # Verify each student can access their own attempt
      assert PageLifecycle.can_access_attempt?(
               resource_attempt1.attempt_guid,
               student1,
               section1
             )

      assert PageLifecycle.can_access_attempt?(
               resource_attempt2.attempt_guid,
               student2,
               section1
             )

      assert PageLifecycle.can_access_attempt?(
               resource_attempt3.attempt_guid,
               student1,
               section2
             )

      # Verify the instructor enrolled can access student attempts
      assert PageLifecycle.can_access_attempt?(
               resource_attempt1.attempt_guid,
               instructor1,
               section1
             )

      assert PageLifecycle.can_access_attempt?(
               resource_attempt2.attempt_guid,
               instructor1,
               section1
             )

      assert PageLifecycle.can_access_attempt?(
               resource_attempt3.attempt_guid,
               instructor2,
               section2
             )

      # Verify one student cannot access another attempt from a student in the
      # same section
      refute PageLifecycle.can_access_attempt?(
               resource_attempt1.attempt_guid,
               student2,
               section1
             )

      # Verify one instructor from another section cannot an attempt from a student in
      # a different section
      refute PageLifecycle.can_access_attempt?(
               resource_attempt1.attempt_guid,
               instructor2,
               section1
             )
    end
  end
end
