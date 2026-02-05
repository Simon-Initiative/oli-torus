defmodule Oli.Delivery.Sections.EnrollmentGuardTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections

  describe "ensure_enrollment_allowed/2" do
    test "allows independent learner users in open and free sections" do
      section = insert(:section, open_and_free: true, lti_1p3_deployment: nil)
      user = insert(:user, independent_learner: true)

      assert :ok = Sections.ensure_enrollment_allowed(user, section)
    end

    test "rejects LMS users in open and free sections" do
      section = insert(:section, open_and_free: true, lti_1p3_deployment: nil)
      user = insert(:user, independent_learner: false)

      assert {:error, :non_independent_user} =
               Sections.ensure_enrollment_allowed(user, section)
    end

    test "allows LMS users in non open and free sections" do
      section = insert(:section, open_and_free: false)
      user = insert(:user, independent_learner: false)

      assert :ok = Sections.ensure_enrollment_allowed(user, section)
    end

    test "rejects independent learners in non open and free sections" do
      section = insert(:section, open_and_free: false)
      user = insert(:user, independent_learner: true)

      assert {:error, :independent_learner_not_allowed} =
               Sections.ensure_enrollment_allowed(user, section)
    end
  end

  describe "ensure_batch_enrollment_allowed/2" do
    test "allows independent learners in open and free sections" do
      section = insert(:section, open_and_free: true, lti_1p3_deployment: nil)
      user_1 = insert(:user, independent_learner: true)
      user_2 = insert(:user, independent_learner: true)

      assert :ok =
               Sections.ensure_batch_enrollment_allowed(
                 [user_1.id, user_2.id],
                 section
               )
    end

    test "rejects lists that include LMS users" do
      section = insert(:section, open_and_free: true, lti_1p3_deployment: nil)
      user_1 = insert(:user, independent_learner: true)
      user_2 = insert(:user, independent_learner: false)

      assert {:error, {:non_independent_users, ids}} =
               Sections.ensure_batch_enrollment_allowed(
                 [user_1.id, user_2.id],
                 section
               )

      assert Enum.member?(ids, user_2.id)
    end

    test "allows LMS users in non open and free sections" do
      section = insert(:section, open_and_free: false)
      user = insert(:user, independent_learner: false)

      assert :ok = Sections.ensure_batch_enrollment_allowed([user.id], section)
    end

    test "rejects independent learners in non open and free sections" do
      section = insert(:section, open_and_free: false)
      user = insert(:user, independent_learner: true)

      assert {:error, {:independent_learner_not_allowed, ids}} =
               Sections.ensure_batch_enrollment_allowed([user.id], section)

      assert Enum.member?(ids, user.id)
    end
  end
end
