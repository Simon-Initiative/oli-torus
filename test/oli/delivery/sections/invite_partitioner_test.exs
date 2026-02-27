defmodule Oli.Delivery.Sections.InvitePartitionerTest do
  use Oli.DataCase

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.InvitePartitioner

  describe "partition/2" do
    test "classifies an existing user with mixed-case input as not_enrolled" do
      section = insert(:section)
      _user = insert(:user, email: "MIhachi@DallasCollege.edu")

      grouped = InvitePartitioner.partition(section.slug, ["MIhachi@dallascollege.edu"])

      assert grouped.non_existing_users == []
      assert grouped.not_enrolled_users == ["mihachi@dallascollege.edu"]
      assert grouped.pending_confirmation == []
      assert grouped.rejected == []
      assert grouped.suspended == []
      assert grouped.enrolled == []
    end

    test "normalizes and deduplicates non-existing emails" do
      section = insert(:section)

      grouped =
        InvitePartitioner.partition(section.slug, [
          " Example@Email.com ",
          "example@email.com",
          "EXAMPLE@EMAIL.COM"
        ])

      assert grouped.non_existing_users == ["example@email.com"]
      assert grouped.not_enrolled_users == []
      assert grouped.pending_confirmation == []
      assert grouped.rejected == []
      assert grouped.suspended == []
      assert grouped.enrolled == []
    end

    test "partitions users by current enrollment status and existence" do
      section = insert(:section)

      enrolled = insert(:user, email: "enrolled@example.com")
      pending = insert(:user, email: "pending@example.com")
      rejected = insert(:user, email: "rejected@example.com")
      suspended = insert(:user, email: "suspended@example.com")
      _not_enrolled = insert(:user, email: "notenrolled@example.com")

      Sections.enroll(
        [enrolled.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Sections.enroll(
        [pending.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :pending_confirmation
      )

      Sections.enroll(
        [rejected.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :rejected
      )

      Sections.enroll(
        [suspended.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :suspended
      )

      grouped =
        InvitePartitioner.partition(section.slug, [
          "ENROLLED@example.com",
          "pending@example.com",
          "REJECTED@example.com",
          "suspended@example.com",
          "NOTENROLLED@example.com",
          "newuser@example.com"
        ])

      assert MapSet.new(grouped.enrolled) == MapSet.new(["enrolled@example.com"])
      assert MapSet.new(grouped.pending_confirmation) == MapSet.new(["pending@example.com"])
      assert MapSet.new(grouped.rejected) == MapSet.new(["rejected@example.com"])
      assert MapSet.new(grouped.suspended) == MapSet.new(["suspended@example.com"])
      assert MapSet.new(grouped.not_enrolled_users) == MapSet.new(["notenrolled@example.com"])
      assert MapSet.new(grouped.non_existing_users) == MapSet.new(["newuser@example.com"])
    end
  end
end
