
defmodule Oli.Lti_1p3.PlatformRolesTest do
  use Oli.DataCase

  alias Oli.Lti_1p3.PlatformRoles
  alias Oli.Lti_1p3.Lti_1p3_User

  describe "platform roles" do

    test "list_roles returns an ordered list of all roles that match values returned by get_role with the corresponding atom" do
      assert PlatformRoles.list_roles() == [
        PlatformRoles.get_role(:system_administrator),
        PlatformRoles.get_role(:system_none),
        PlatformRoles.get_role(:system_account_admin),
        PlatformRoles.get_role(:system_creator),
        PlatformRoles.get_role(:system_sys_admin),
        PlatformRoles.get_role(:system_sys_support),
        PlatformRoles.get_role(:system_user),
        PlatformRoles.get_role(:institution_administrator),
        PlatformRoles.get_role(:institution_faculty),
        PlatformRoles.get_role(:institution_guest),
        PlatformRoles.get_role(:institution_none),
        PlatformRoles.get_role(:institution_other),
        PlatformRoles.get_role(:institution_staff),
        PlatformRoles.get_role(:institution_student),
        PlatformRoles.get_role(:institution_alumni),
        PlatformRoles.get_role(:institution_instructor),
        PlatformRoles.get_role(:institution_learner),
        PlatformRoles.get_role(:institution_member),
        PlatformRoles.get_role(:institution_mentor),
        PlatformRoles.get_role(:institution_observer),
        PlatformRoles.get_role(:institution_prospective_student),
      ]
    end

    test "get_role returns a role with state: :loaded" do
      role = PlatformRoles.get_role(:institution_learner)

      assert Ecto.get_meta(role, :state) == :loaded
    end

    test "get_role_by_uri returns a role with state: :loaded" do
      role = PlatformRoles.get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner")

      assert Ecto.get_meta(role, :state) == :loaded
    end

    test "get_role returns nil for invalid role atom" do
      role = PlatformRoles.get_role(:unknown)

      assert role == nil
    end

    test "get_role_by_uri returns nil for invalid role uri" do
      role = PlatformRoles.get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#SomeUknownRole")

      assert role == nil
    end

    test "get_roles_by_uris returns all valid roles from a list of uris" do
      roles = PlatformRoles.get_roles_by_uris([
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner"])

      assert roles == [
        PlatformRoles.get_role(:institution_instructor),
        PlatformRoles.get_role(:institution_learner)
      ]
    end

    test "contains_role? returns true if a list of roles contains a given role" do
      roles = PlatformRoles.get_roles_by_uris([
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner"])

      assert PlatformRoles.contains_role?(roles, PlatformRoles.get_role(:institution_instructor)) == true
      assert PlatformRoles.contains_role?(roles, PlatformRoles.get_role(:institution_learner)) == true
      assert PlatformRoles.contains_role?(roles, PlatformRoles.get_role(:institution_mentor)) == false
    end

    test "get_highest_role returns the highest level role from a list of roles" do
      roles = PlatformRoles.get_roles_by_uris([
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner"])

      assert PlatformRoles.get_highest_role(roles) == PlatformRoles.get_role(:institution_instructor)

      roles = PlatformRoles.get_roles_by_uris(["http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner"])

      assert PlatformRoles.get_highest_role(roles) == PlatformRoles.get_role(:institution_learner)

      roles = []

      assert PlatformRoles.get_highest_role(roles) == nil
    end

    test "has_role? returns true if a user has a given role" do
      user = struct(Lti_1p3_User.Mock, %{
        platform_role_uris: [
          "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner",
        ],
        context_role_uris: [],
      })

      assert PlatformRoles.has_role?(user, PlatformRoles.get_role(:institution_instructor)) == false
      assert PlatformRoles.has_role?(user, PlatformRoles.get_role(:institution_learner)) == true
    end

    test "has_roles? with :any returns true if a user has any of the given roles" do
      user = struct(Lti_1p3_User.Mock, %{
        platform_role_uris: [
          "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner",
        ],
        context_role_uris: [],
      })

      assert PlatformRoles.has_roles?(user, [PlatformRoles.get_role(:institution_instructor)], :any) == false
      assert PlatformRoles.has_roles?(user, [PlatformRoles.get_role(:institution_instructor), PlatformRoles.get_role(:institution_learner)], :any) == true
      assert PlatformRoles.has_roles?(user, [PlatformRoles.get_role(:institution_learner)], :any) == true
      assert PlatformRoles.has_roles?(user, [], :any) == false
    end

    test "has_roles? with :all returns true if a user has all of the given roles" do
      user = struct(Lti_1p3_User.Mock, %{
        platform_role_uris: [
          "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor",
          "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner",
        ],
        context_role_uris: [],
      })

      assert PlatformRoles.has_roles?(user, [PlatformRoles.get_role(:institution_instructor)], :all) == true
      assert PlatformRoles.has_roles?(user, [PlatformRoles.get_role(:institution_instructor), PlatformRoles.get_role(:institution_learner)], :all) == true
      assert PlatformRoles.has_roles?(user, [PlatformRoles.get_role(:institution_learner), PlatformRoles.get_role(:institution_mentor)], :all) == false
      assert PlatformRoles.has_roles?(user, [], :all) == true
    end
  end
end
