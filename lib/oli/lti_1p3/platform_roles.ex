defmodule Oli.Lti_1p3.PlatformRoles do
  alias Oli.Lti_1p3.PlatformRole
  alias Oli.Lti_1p3.Lti_1p3_User

  # Core system roles
  @system_administrator %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/system/person#Administrator"
  }

  @system_none %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/system/person#None"
  }

  # Non‑core system roles
  @system_account_admin %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/system/person#AccountAdmin"
  }

  @system_creator %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/system/person#Creator"
  }

  @system_sys_admin %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/system/person#SysAdmin"
  }

  @system_sys_support %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/system/person#SysSupport"
  }

  @system_user %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/system/person#User"
  }

  # Core institution roles
  @institution_administrator %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Administrator"
  }

  @institution_faculty %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Faculty"
  }

  @institution_guest %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Guest"
  }

  @institution_none %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#None"
  }

  @institution_other %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Other"
  }

  @institution_staff %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Staff"
  }

  @institution_student %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student"
  }

  # Non‑core institution roles
  @institution_alumni %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Alumni"
  }

  @institution_instrcutor %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor"
  }

  @institution_learner %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner"
  }
  @institution_member %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Member"
  }
  @institution_mentor %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Mentor"
  }
  @institution_observer %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Observer"
  }
  @institution_prospective_student %PlatformRole{
    uri: "http://purl.imsglobal.org/vocab/lis/v2/institution/person#ProspectiveStudent"
  }

  def list_roles(), do: [
    @system_administrator,
    @system_none,
    @system_account_admin,
    @system_creator,
    @system_sys_admin,
    @system_sys_support,
    @system_user,
    @institution_administrator,
    @institution_faculty,
    @institution_guest,
    @institution_none,
    @institution_other,
    @institution_staff,
    @institution_student,
    @institution_alumni,
    @institution_instrcutor,
    @institution_learner,
    @institution_member,
    @institution_mentor,
    @institution_observer,
    @institution_prospective_student,
  ]

  @doc """
  Returns a role from a given atom if it is valid, otherwise returns nil
  """
  def get_role(:system_administrator), do: @system_administrator
  def get_role(:system_none), do: @system_none
  def get_role(:system_account_admin), do: @system_account_admin
  def get_role(:system_creator), do: @system_creator
  def get_role(:system_sys_admin), do: @system_sys_admin
  def get_role(:system_sys_support), do: @system_sys_support
  def get_role(:system_user), do: @system_user
  def get_role(:institution_administrator), do: @institution_administrator
  def get_role(:institution_faculty), do: @institution_faculty
  def get_role(:institution_guest), do: @institution_guest
  def get_role(:institution_none), do: @institution_none
  def get_role(:institution_other), do: @institution_other
  def get_role(:institution_staff), do: @institution_staff
  def get_role(:institution_student), do: @institution_student
  def get_role(:institution_alumni), do: @institution_alumni
  def get_role(:institution_instrcutor), do: @institution_instrcutor
  def get_role(:institution_learner), do: @institution_learner
  def get_role(:institution_member), do: @institution_member
  def get_role(:institution_mentor), do: @institution_mentor
  def get_role(:institution_observer), do: @institution_observer
  def get_role(:institution_prospective_student), do: @institution_prospective_student
  def get_role(_invalid), do: nil

  @doc """
  Returns a role from a given uri if it is valid, otherwise returns nil
  """
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/system/person#Administrator"), do: @system_administrator
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/system/person#None"), do: @system_none
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/system/person#AccountAdmin"), do: @system_account_admin
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/system/person#Creator"), do: @system_creator
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/system/person#SysAdmin"), do: @system_sys_admin
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/system/person#SysSupport"), do: @system_sys_support
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/system/person#User"), do: @system_user
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Administrator"), do: @institution_administrator
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Faculty"), do: @institution_faculty
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Guest"), do: @institution_guest
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#None"), do: @institution_none
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Other"), do: @institution_other
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Staff"), do: @institution_staff
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student"), do: @institution_student
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Alumni"), do: @institution_alumni
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor"), do: @institution_instrcutor
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Learner"), do: @institution_learner
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Member"), do: @institution_member
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Mentor"), do: @institution_mentor
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#Observer"), do: @institution_observer
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/institution/person#ProspectiveStudent"), do: @institution_prospective_student
  def get_role_by_uri(_invalid), do: nil

  @doc """
  Returns all valid roles from a list of uris
  """
  @spec get_roles_by_uris([String.t()]) :: [%PlatformRole{}]
  def get_roles_by_uris(uris) do
    # create a list only containing valid roles
    uris
      |> Enum.map(&(get_role_by_uri(&1)))
      |> Enum.filter(&(&1 != nil))
  end

  @doc """
  Returns true if a list of roles contains a given role
  """
  @spec contains_role?([PlatformRole.t()], PlatformRole.t()) :: boolean()
  def contains_role?(roles, role) when is_list(roles) do
    Enum.any?(roles, fn r -> r.uri == role.uri end)
  end

  @doc """
  Returns true if a user has a given role
  """
  @spec has_role?(Lti_1p3_User.t(), PlatformRole.t()) :: boolean()
  def has_role?(user, role) do
    roles = Lti_1p3_User.get_platform_roles(user)
    Enum.any?(roles, fn r -> r.uri == role.uri end)
  end

  @doc """
  Returns true if a user has any of the given roles
  """
  @spec has_roles?(Lti_1p3_User.t(), [PlatformRole.t()], :any) :: boolean()
  def has_roles?(user, roles, :any) when is_list(roles) do
    user_roles_map = get_user_roles_map(user)
    Enum.any?(roles, fn r -> user_roles_map[r.uri] == true end)
  end

  @doc """
  Returns true if a user has all of the given roles
  """
  @spec has_roles?(Lti_1p3_User.t(), [PlatformRole.t()], :all) :: boolean()
  def has_roles?(user, roles, :all) when is_list(roles) do
    user_roles_map = get_user_roles_map(user)
    Enum.all?(roles, fn r -> user_roles_map[r.uri] == true end)
  end

  # Returns a map with keys of all role uris with value true if the user has the role, false otherwise
  defp get_user_roles_map(user) do
    user_roles = Lti_1p3_User.get_platform_roles(user)
    Enum.reduce(list_roles(), %{}, fn r, acc -> Map.put_new(acc, r.uri, Enum.any?(user_roles, &(&1.uri == r.uri))) end)
  end

end
