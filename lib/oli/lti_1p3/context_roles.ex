defmodule Oli.Lti_1p3.ContextRoles do
  alias Oli.Lti_1p3.ContextRole
  alias Oli.Lti_1p3.Lti_1p3_User

  # Core context roles
  @context_administrator %ContextRole{
    id: 1,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#Administrator"
  }

  @context_content_developer %ContextRole{
    id: 2,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#ContentDeveloper"
  }

  @context_instructor %ContextRole{
    id: 3,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
  }

  @context_learner %ContextRole{
    id: 4,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
  }

  @context_mentor %ContextRole{
    id: 5,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#Mentor"
  }

  # Non‑core context roles
  @context_manager %ContextRole{
    id: 6,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#Manager"
  }

  @context_member %ContextRole{
    id: 7,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#Member"
  }

  @context_officer %ContextRole{
    id: 8,
    uri: "http://purl.imsglobal.org/vocab/lis/v2/membership#Officer"
  }

  def list_roles(:unloaded), do: [
    @context_administrator,
    @context_content_developer,
    @context_instructor,
    @context_learner,
    @context_mentor,
    @context_manager,
    @context_member,
    @context_officer,
  ]

  def list_roles(), do: Enum.map list_roles(:unloaded), &role_as_loaded/1

  @doc """
  Returns a role from a given atom if it is valid, otherwise returns nil
  """
  def get_role(:context_administrator), do: @context_administrator |> role_as_loaded
  def get_role(:context_content_developer), do: @context_content_developer |> role_as_loaded
  def get_role(:context_instructor), do: @context_instructor |> role_as_loaded
  def get_role(:context_learner), do: @context_learner |> role_as_loaded
  def get_role(:context_mentor), do: @context_mentor |> role_as_loaded
  def get_role(:context_manager), do: @context_manager |> role_as_loaded
  def get_role(:context_member), do: @context_member |> role_as_loaded
  def get_role(:context_officer), do: @context_officer |> role_as_loaded
  def get_role(_invalid), do: nil

  @doc """
  Returns a role from a given uri if it is valid, otherwise returns nil
  """
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Administrator"), do: @context_administrator |> role_as_loaded
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#ContentDeveloper"), do: @context_content_developer |> role_as_loaded
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"), do: @context_instructor |> role_as_loaded
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"), do: @context_learner |> role_as_loaded
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Mentor"), do: @context_mentor |> role_as_loaded
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Manager"), do: @context_manager |> role_as_loaded
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Member"), do: @context_member |> role_as_loaded
  def get_role_by_uri("http://purl.imsglobal.org/vocab/lis/v2/membership#Officer"), do: @context_officer |> role_as_loaded
  def get_role_by_uri(_invalid), do: nil

  @doc """
  Returns all valid roles from a list of uris
  """
  @spec get_roles_by_uris([String.t()]) :: [ContextRole.t()]
  def get_roles_by_uris(uris) do
    # create a list only containing valid roles
    uris
      |> Enum.map(&(get_role_by_uri(&1)))
      |> Enum.filter(&(&1 != nil))
  end

  @doc """
  Returns true if a list of roles contains a given role
  """
  @spec contains_role?([ContextRole.t()], ContextRole.t()) :: boolean()
  def contains_role?(roles, role) when is_list(roles) do
    Enum.any?(roles, fn r -> r.uri == role.uri end)
  end

  @doc """
  Returns the highest level role from a list of roles. This function assumes roles have an
  ordinality which is defined by list_roles()
  """
  @spec get_highest_role([ContextRole.t()]) :: ContextRole.t()
  def get_highest_role(roles) when is_list(roles) do
    roles_map = context_roles_as_map(roles)
    Enum.find(list_roles(), fn r -> roles_map[r.uri] == true end)
  end

  @doc """
  Returns true if a user has a given role
  """
  @spec has_role?(Lti_1p3_User.t(), String.t(), ContextRole.t()) :: boolean()
  def has_role?(user, context_id, role) when is_struct(user) do
    roles = Lti_1p3_User.get_context_roles(user, context_id)
    Enum.any?(roles, fn r -> r.uri == role.uri end)
  end

  @doc """
  Returns true if a user has any of the given roles
  """
  @spec has_roles?(Lti_1p3_User.t(), String.t(), [ContextRole.t()], :any) :: boolean()
  def has_roles?(user, context_id, roles, :any) when is_struct(user) and is_list(roles) do
    context_roles = Lti_1p3_User.get_context_roles(user, context_id)
    context_roles_map = context_roles_as_map(context_roles)
    Enum.any?(roles, fn r -> context_roles_map[r.uri] == true end)
  end

  # Returns true if a user has all of the given roles
  @spec has_roles?(Lti_1p3_User.t(), String.t(), [ContextRole.t()], :all) :: boolean()
  def has_roles?(user, context_id, roles, :all) when is_struct(user) and is_list(roles) do
    context_roles = Lti_1p3_User.get_context_roles(user, context_id)
    context_roles_map = context_roles_as_map(context_roles)
    Enum.all?(roles, fn r -> context_roles_map[r.uri] == true end)
  end

  # Returns a map with keys of all role uris with value true if the user has the role, false otherwise
  defp context_roles_as_map(context_roles) do
    Enum.reduce(list_roles(), %{}, fn r, acc -> Map.put_new(acc, r.uri, Enum.any?(context_roles, &(&1.uri == r.uri))) end)
  end

  defp role_as_loaded(role) do
    role |> Ecto.put_meta(state: :loaded)
  end

end
