
defmodule Oli.Lti_1p3.ContextRolesTest do
  use Oli.DataCase

  alias Oli.Lti_1p3.ContextRoles
  alias Oli.Lti_1p3.Lti_1p3_User

  describe "context roles" do

    test "list_roles returns an ordered list of all roles that match values returned by get_role with the corresponding atom" do
      assert ContextRoles.list_roles() == [
        ContextRoles.get_role(:context_administrator),
        ContextRoles.get_role(:context_content_developer),
        ContextRoles.get_role(:context_instructor),
        ContextRoles.get_role(:context_learner),
        ContextRoles.get_role(:context_mentor),
        ContextRoles.get_role(:context_manager),
        ContextRoles.get_role(:context_member),
        ContextRoles.get_role(:context_officer),
      ]
    end

    test "get_role returns a role with state: :loaded" do
      role = ContextRoles.get_role(:context_administrator)

      assert Ecto.get_meta(role, :state) == :loaded
    end

    test "get_role_by_uri returns a role with state: :loaded" do
      role = ContextRoles.get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Administrator")

      assert Ecto.get_meta(role, :state) == :loaded
    end

    test "get_role returns nil for invalid role atom" do
      role = ContextRoles.get_role(:unknown)

      assert role == nil
    end

    test "get_role_by_uri returns nil for invalid role uri" do
      role = ContextRoles.get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#SomeUknownRole")

      assert role == nil
    end

    test "get_roles_by_uris returns all valid roles from a list of uris" do
      roles = ContextRoles.get_roles_by_uris([
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"])

      assert roles == [
        ContextRoles.get_role(:context_instructor),
        ContextRoles.get_role(:context_learner)
      ]
    end

    test "contains_role? returns true if a list of roles contains a given role" do
      roles = ContextRoles.get_roles_by_uris([
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"])

      assert ContextRoles.contains_role?(roles, ContextRoles.get_role(:context_instructor)) == true
      assert ContextRoles.contains_role?(roles, ContextRoles.get_role(:context_learner)) == true
      assert ContextRoles.contains_role?(roles, ContextRoles.get_role(:context_mentor)) == false
    end

    test "get_highest_role returns the highest level role from a list of roles" do
      roles = ContextRoles.get_roles_by_uris([
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"])

      assert ContextRoles.get_highest_role(roles) == ContextRoles.get_role(:context_instructor)

      roles = ContextRoles.get_roles_by_uris(["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"])

      assert ContextRoles.get_highest_role(roles) == ContextRoles.get_role(:context_learner)

      roles = []

      assert ContextRoles.get_highest_role(roles) == nil
    end

    test "has_role? returns true if a user has a given role" do
      user = struct(Lti_1p3_User.Mock, %{
        platform_role_uris: [],
        context_role_uris: [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
        ],
      })

      assert ContextRoles.has_role?(user, "context-id", ContextRoles.get_role(:context_instructor)) == false
      assert ContextRoles.has_role?(user, "context-id", ContextRoles.get_role(:context_learner)) == true
    end

    test "has_roles? with :any returns true if a user has any of the given roles" do
      user = struct(Lti_1p3_User.Mock, %{
        platform_role_uris: [],
        context_role_uris: [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
        ],
      })

      assert ContextRoles.has_roles?(user, "context-id", [ContextRoles.get_role(:context_instructor)], :any) == false
      assert ContextRoles.has_roles?(user, "context-id", [ContextRoles.get_role(:context_instructor), ContextRoles.get_role(:context_learner)], :any) == true
      assert ContextRoles.has_roles?(user, "context-id", [ContextRoles.get_role(:context_learner)], :any) == true
      assert ContextRoles.has_roles?(user, "context-id", [], :any) == false
    end

    test "has_roles? with :all returns true if a user has all of the given roles" do
      user = struct(Lti_1p3_User.Mock, %{
        platform_role_uris: [],
        context_role_uris: [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
        ],
      })

      assert ContextRoles.has_roles?(user, "context-id", [ContextRoles.get_role(:context_instructor)], :all) == true
      assert ContextRoles.has_roles?(user, "context-id", [ContextRoles.get_role(:context_instructor), ContextRoles.get_role(:context_learner)], :all) == true
      assert ContextRoles.has_roles?(user, "context-id", [ContextRoles.get_role(:context_learner), ContextRoles.get_role(:context_mentor)], :all) == false
      assert ContextRoles.has_roles?(user, "context-id", [], :all) == true
    end
  end
end
