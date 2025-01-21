defmodule Oli.Accounts do
  import Ecto.Query, warn: false
  import Oli.Utils, only: [value_or: 2]

  alias Ecto.Multi

  alias Oli.Accounts.{
    User,
    UserToken,
    UserNotifier,
    Author,
    AuthorToken,
    AuthorNotifier,
    SystemRole,
    UserBrowseOptions,
    AuthorBrowseOptions,
    AuthorPreferences,
    UserPreferences
  }

  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.Course.Project

  alias Oli.Groups
  alias Oli.Groups.CommunityAccount
  alias Oli.Institutions.Institution
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections.{Section, Enrollment}
  alias Lti_1p3.DataProviders.EctoProvider

  def browse_users(
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %UserBrowseOptions{} = options
      ) do
    filter_by_guest =
      if options.include_guests do
        true
      else
        dynamic([s, _], s.guest == false)
      end

    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        text_search = String.trim(options.text_search)

        dynamic(
          [s, _],
          ilike(s.name, ^"%#{text_search}%") or
            ilike(s.email, ^"%#{text_search}%") or
            ilike(s.given_name, ^"%#{text_search}%") or
            ilike(s.family_name, ^"%#{text_search}%")
        )
      end

    query =
      User
      |> join(:left, [u], e in "enrollments", on: u.id == e.user_id)
      |> join(:left, [u, _e], a in "authors", on: u.author_id == a.id)
      |> where(^filter_by_text)
      |> where(^filter_by_guest)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(:author)
      |> group_by([u, _, _], u.id)
      |> group_by([_, _, a], a.email)
      |> select_merge([u, e, _], %{
        enrollments_count: count(e.id),
        total_count: fragment("count(*) OVER()")
      })

    query =
      case field do
        :enrollments_count -> order_by(query, [_, e, _], {^direction, count(e.id)})
        :author -> order_by(query, [_, _, a], {^direction, a.email})
        _ -> order_by(query, [u, _, _], {^direction, field(u, ^field)})
      end

    Repo.all(query)
  end

  @spec get_users_by_email(list(String.t())) :: list(User.t())
  def get_users_by_email(email_list) do
    User
    |> where([u], u.independent_learner == true and u.email in ^email_list)
    |> select([u], %{
      id: u.id,
      email: u.email
    })
    |> Repo.all()
  end

  @doc """
  Creates multiple invited users
  ## Examples
       iex> bulk_create_invited_users(["email_1@test.com", "email_2@test.com"], %User{id: 1})
      [%User{id: 3}, %User{id: 4}]
  """
  def bulk_create_invited_users(user_emails, inviter_user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    users =
      Enum.map(user_emails, fn email ->
        %{changes: changes} =
          User.invite_changeset(%User{}, %{email: email, invited_by_id: inviter_user.id})

        Enum.into(changes, %{inserted_at: now, updated_at: now})
      end)

    Repo.insert_all(User, users, returning: [:id, :email])
  end

  def create_invited_author(email) do
    %Author{}
    |> Author.invite_changeset(%{email: email})
    |> Repo.insert()
  end

  def browse_authors(
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %AuthorBrowseOptions{} = options
      ) do
    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        text_search = String.trim(options.text_search)

        dynamic(
          [s, _],
          ilike(s.name, ^"%#{text_search}%") or
            ilike(s.email, ^"%#{text_search}%") or
            ilike(s.given_name, ^"%#{text_search}%") or
            ilike(s.family_name, ^"%#{text_search}%")
        )
      end

    query =
      Author
      |> join(:left, [u], e in Oli.Authoring.Authors.AuthorProject, on: u.id == e.author_id)
      |> where(^filter_by_text)
      |> limit(^limit)
      |> offset(^offset)
      |> group_by([u, _], u.id)
      |> select_merge([u, e], %{
        collaborations_count: count(e.project_id),
        total_count: fragment("count(*) OVER()")
      })

    query =
      case field do
        :collaborations_count -> order_by(query, [_, e], {^direction, count(e.project_id)})
        _ -> order_by(query, [p, _], {^direction, field(p, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Returns the list of users.
  ## Examples
      iex> list_users()
      [%User{}, ...]
  """
  def list_users do
    from(u in User,
      left_join: a in Author,
      on: a.id == u.author_id,
      where: u.guest == false,
      preload: [author: a]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of authors.
  ## Examples
      iex> list_authors()
      [%Author{}, ...]
  """
  def list_authors do
    Repo.all(Author)
  end

  #### MER-3835 TODO: Reconcile these functions with new functions at end of module

  @doc """
  Gets a single user.
  Raises `Ecto.NoResultsError` if the User does not exist.
  ## Examples
      iex> get_user!(123)
      %User{}
      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user!(id, preload: preloads), do: Repo.get!(User, id) |> Repo.preload(preloads)

  def get_user(id, preload: preloads), do: Repo.get(User, id) |> Repo.preload(preloads)

  @doc """
  Gets a single user by query parameter
  ## Examples
      iex> get_user_by(sub: "123")
      %User{}
      iex> get_user_by(sub: "111")
      nil
  """
  def get_user_by(clauses), do: Repo.get_by(User, clauses)

  @doc """
  Gets a single independent user by query parameter
  ## Examples
      iex> get_independent_user_by(email: "student1@example.com")
      %User{independent_learner: true, ...}
      iex> get_independent_user_by(email: "student2@example.com")
      nil
  """
  def get_independent_user_by(clauses),
    do: Repo.get_by(User, Enum.into([independent_learner: true], clauses))

  @doc """
  Gets a single user with platform roles and author preloaded
  Returns `nil` if the User does not exist.
  ## Examples
      iex> get_user_with_roles(123)
      %User{}
      iex> get_user_with_roles(456)
      nil

  """
  def get_user_with_roles(id) do
    from(user in User,
      where: user.id == ^id,
      left_join: platform_roles in assoc(user, :platform_roles),
      left_join: author in assoc(user, :author),
      preload: [platform_roles: platform_roles, author: author]
    )
    |> Repo.one()
  end

  @doc """
  Creates a guest user.
  ## Examples
      iex> create_guest_user(%{field: value})
      {:ok, %User{}}
      iex> create_guest_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_guest_user(attrs \\ %{}) do
    %User{
      # generate a unique sub identifier which is also used so a user can access
      # their progress in the future or using a different browser
      sub: UUID.uuid4(),
      guest: true
    }
    |> User.noauth_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  ## Examples
      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}
      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.noauth_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  ## Examples
      iex> delete_user(user)
      {:ok, %User{}}
      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Updates user details if a record matches the given `sub` and `institution_id`. If no user is found, creates a new user.

  The function checks for a user who is enrolled in an active section, where the section and enrollment belong to the specified institution.

  ## Examples

      iex> insert_or_update_lms_user(%{sub: "123", field: value}, institution_id)
      {:ok, %User{}}    -> # Inserted or updated with success
      {:error, changeset} -> # Something went wrong

  ## Parameters
  - `changes`: A map containing the user details to be updated or inserted.
  - `institution_id`: The ID of the institution to match the user's enrollment.
  """

  def insert_or_update_lms_user(%{sub: sub} = changes, institution_id) do
    # First see if we can find a user that matches the sub and institution id exactly. This
    # will end up being the most common case (on all launches for a user beyond the first)
    user =
      case Repo.get_by(User, sub: sub, lti_institution_id: institution_id) do
        # If not found directly, do another read of ALL users with this sub.  This step
        # isn't strictly necessary (we could just call find_user_through_enrollment), but
        # do it to make this more robust by reducing the need to rely on the enrollment.
        nil ->
          case get_all_users_by_sub(sub) do
            # If no users with this sub, we can be absolutely sure that we need to create a new user
            [] -> nil
            # Otherwise, we now need to check to see if one of these users is enrolled in a section
            # that is pinned to this institution
            _ -> find_user_through_enrollment(sub, institution_id)
          end

        user ->
          user
      end

    case user do
      nil -> create_lms_user(changes)
      user -> update_lms_user(user, changes)
    end
  end

  defp get_all_users_by_sub(sub) do
    from(u in User, where: u.sub == ^sub) |> Repo.all()
  end

  defp find_user_through_enrollment(sub, institution_id) do
    # using enrollment records, we can infer the user's institution. This is because
    # an LTI user can be enrolled in multiple sections, but all sections must be from
    # the same institution.
    results =
      from(e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        join: u in User,
        on: e.user_id == u.id,
        join: institution in Institution,
        on: s.institution_id == institution.id,
        where: u.sub == ^sub and institution.id == ^institution_id,
        select: u,
        order_by: [desc: u.inserted_at]
      )
      |> Repo.all()

    # We must handle the fact that duplicate records can exist in the result set, in
    # this case we select the "most recently inserted" user record
    case results do
      [user | _] -> user
      [] -> nil
    end
  end

  defp create_lms_user(%{sub: sub} = changes) do
    %User{sub: sub, independent_learner: false}
    |> User.noauth_changeset(changes)
    |> Repo.insert()
  end

  defp update_lms_user(%User{} = user, changes) do
    user
    |> User.noauth_changeset(changes)
    |> Repo.update()
  end

  @doc """
  Updates user details if a record matches sub, otherwise creates a new user

  ## Examples

      iex> insert_or_update_sso_user(%{sub, "123", field: value})
      {:ok, %User{}}    -> # Inserted or updated with success
      {:error, changeset}         -> # Something went wrong

  """
  def insert_or_update_sso_user(%{sub: sub} = changes) do
    # TODO: fix collision of user subs along different institutions that use SSO.
    Repo.get_by(User, sub: sub)
    |> insert_or_update_external_user(changes)
  end

  defp insert_or_update_external_user(user, %{sub: sub} = changes) do
    case user do
      nil -> %User{sub: sub, independent_learner: false}
      user -> user
    end
    |> User.external_user_changeset(changes)
    |> Repo.insert_or_update()
    |> case do
      {:ok, %User{}} = res ->
        res

      error ->
        error
    end
  end

  @doc """
  Preloads the user's LTI params.
  """
  def load_lti_params(user) do
    user
    |> Repo.preload(:lti_params)
  end

  @doc """
  Updates the platform roles associated with a user
  ## Examples
      iex> update_user_platform_roles(user, roles)
      {:ok, user}       -> # Updated with success

      iex> update_user_platform_roles(user, roles)
      {:error, changeset} -> # Something went wrong
  """
  def update_user_platform_roles(%User{} = user, roles) do
    roles = Lti_1p3.DataProviders.EctoProvider.Marshaler.to(roles)

    user
    |> Repo.preload([:platform_roles])
    |> User.noauth_changeset()
    |> Ecto.Changeset.put_assoc(:platform_roles, roles)
    |> Repo.update()
  end

  @doc """
    Updates the context role for a specific enrollment.
  """

  def update_user_context_role(enrollment, role) do
    context_role = EctoProvider.Marshaler.to([role])

    res =
      enrollment
      |> Repo.preload([:context_roles])
      |> Enrollment.changeset(%{})
      |> Ecto.Changeset.put_assoc(:context_roles, context_role)
      |> Repo.update()

    case res do
      {:ok, %Enrollment{}} ->
        res

      error ->
        error
    end
  end

  @doc """
  Preloads the user's platform roles.
  """
  def preload_platform_roles(%User{} = user) do
    Repo.preload(user, :platform_roles)
  end

  def preload_platform_roles(nil), do: nil

  @doc """
  Preloads the user's linked authoring account.
  """
  def preload_linked_author(%User{} = user) do
    Repo.preload(user, :author)
  end

  def preload_linked_author(nil), do: nil

  @doc """
  Links a User to Author account

  ## Examples
      iex> link_user_author_account(user, author_id)
      {:ok, %User{}}
      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def link_user_author_account(nil, _author),
    do:
      throw(
        "No current_user to link to author. This function should only be called in an LTI context"
      )

  def link_user_author_account(_user, nil),
    do:
      throw("No author to link. This function should only be called after an author is logged in")

  def link_user_author_account(user, author) do
    update_user(user, %{author_id: author.id})
  end

  def unlink_user_author_account(user) do
    update_user(user, %{author_id: nil})
  end

  @doc """
  Returns true if a user belongs to an LMS.
  """
  def is_lms_user?(nil), do: false

  def is_lms_user?(email) do
    query =
      from user in User,
        where: user.email == ^email and user.independent_learner == false

    Repo.exists?(query)
  end

  # MER-3835 TODO: reconcile with new functions below

  def at_least_content_admin?(%Author{system_role_id: system_role_id}) do
    SystemRole.role_id().content_admin == system_role_id or
      SystemRole.role_id().account_admin == system_role_id or
      SystemRole.role_id().system_admin == system_role_id
  end

  def at_least_content_admin?(_), do: false

  def at_least_account_admin?(%Author{system_role_id: system_role_id}) do
    SystemRole.role_id().account_admin == system_role_id or
      SystemRole.role_id().system_admin == system_role_id
  end

  def at_least_account_admin?(_), do: false

  @doc """
  Returns true if an author has some role admin.
  """

  def is_admin?(%Author{system_role_id: system_role_id}) do
    system_role_id in [
      SystemRole.role_id().system_admin,
      SystemRole.role_id().account_admin,
      SystemRole.role_id().content_admin
    ]
  end

  def is_admin?(_), do: false

  @doc """
  Returns true if an author has some role admin. System admins have all roles by definition.

  This function can either accept the role_id, typically provided in the long form:

  ## Examples
      iex> has_admin_role?(author, SystemRole.role_id().content_admin)
      false

      iex> has_admin_role?(author, SystemRole.role_id().account_admin)
      true

      iex> has_admin_role?(author, SystemRole.role_id().system_admin)
      false

  or the role can also be passed as a short-hand key form:

  ## Examples
      iex> has_admin_role?(author, :content_admin)
      false

      iex> has_admin_role?(author, :account_admin)
      true

      iex> has_admin_role?(author, :system_admin)
      false

  """
  def has_admin_role?(%Author{system_role_id: system_role_id}, role_id)
      when is_integer(role_id) do
    system_role_id == role_id or system_role_id == SystemRole.role_id().system_admin
  end

  def has_admin_role?(%Author{system_role_id: system_role_id}, role) when is_atom(role) do
    system_role_id == SystemRole.role_id()[role] or
      system_role_id == SystemRole.role_id().system_admin
  end

  def has_admin_role?(_, _), do: false

  @doc """
  Returns true if an author is a community admin.
  """
  def is_community_admin?(%Author{community_admin_count: community_admin_count}) do
    community_admin_count > 0
  end

  @doc """
  Returns an author if one matches given email, or creates and returns a new author

  ## Examples
      iex> insert_or_update_author(%{field: value})
      {:ok, %Author{}}
  """
  def insert_or_update_author(%{email: email} = changes) do
    case Repo.get_by(Author, email: email) do
      nil -> %Author{}
      author -> author
    end
    |> Author.noauth_changeset(changes)
    |> Repo.insert_or_update()
  end

  @doc """
  Updates an author.
  ## Examples
      iex> update_author(author, %{field: new_value})
      {:ok, %Author{}}
      iex> update_author(author, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_author(%Author{} = author, attrs) do
    author
    |> Author.noauth_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single author.
  Raises `Ecto.NoResultsError` if the Author does not exist.
  ## Examples
      iex> get_author!(123)
      %Author{}
      iex> get_author!(456)
      ** (Ecto.NoResultsError)

  """
  def get_author!(id), do: Repo.get!(Author, id)

  @doc """
    Gets a single author.
    Returns nil if the Author does not exist.
    ## Examples
      iex> get_author(123)
      %Author{}
      iex> get_author(456)
      nil

  """
  def get_author(id), do: Repo.get(Author, id)

  @doc """
  Gets a single author with the count of communities for which the author is an admin.

  ## Examples
      iex> get_author_with_community_admin_count(1)
      %Author{community_admin_count: 1}

      iex> get_author_with_community_admin_count(456)
      nil

  """
  def get_author_with_community_admin_count(id) do
    from(
      author in Author,
      left_join: community_account in CommunityAccount,
      on: community_account.author_id == author.id and community_account.is_admin == true,
      where: author.id == ^id,
      group_by: author.id,
      select: author,
      select_merge: %{
        community_admin_count: count(community_account)
      }
    )
    |> Repo.one()
  end

  @doc """
  Deletes an author.
  ## Examples
      iex> delete_author(author)
      {:ok, %Author{}}
      iex> delete_author(author)
      {:error, %Ecto.Changeset{}}
  """
  def delete_author(%Author{} = author) do
    Repo.delete(author)
  end

  @doc """
  Searches for a list of authors with an email matching the exact string
  """
  def search_authors_matching(query) do
    Repo.all(
      from(author in Author,
        where: ilike(author.email, ^query)
      )
    )
  end

  @doc """
  Returns true if a author exists
  """
  def author_with_email_exists?(email) do
    email = String.downcase(email)

    case Repo.get_by(Author, email: email) do
      nil -> false
      _author -> true
    end
  end

  @doc """
  Returns an author preference using the key provided. If the preference isn't set or
  the author preferences have not been created yet, the default value will be returned.

  Accepts an Author struct or author id. If an id is given, the latest author record
  will be queried from the database. Otherwise, the preferences in the Author struct
  is used.

  See AuthorPreferences for available key options
  """
  def get_author_preference(author, key, default \\ nil)

  def get_author_preference(%Author{preferences: preferences}, key, default) do
    preferences
    |> value_or(%AuthorPreferences{})
    |> get_preference(key, default)
  end

  def get_author_preference(author_id, key, default) when is_integer(author_id) do
    author_id
    |> get_author!()
    |> get_author_preference(key, default)
  end

  @doc """
  Returns a user preference using the key provided. If the preference isn't set or
  the user preferences have not been created yet, the default value will be returned.

  Accepts a User struct or user id. If an id is given, the latest user record
  will be queried from the database. Otherwise, the preferences in the User struct
  is used.

  See UserPreferences for available key options
  """
  def get_user_preference(user, key, default \\ nil)

  def get_user_preference(%User{preferences: preferences}, key, default) do
    preferences
    |> value_or(%UserPreferences{})
    |> get_preference(key, default)
  end

  def get_user_preference(user_id, key, default) when is_integer(user_id) do
    user_id
    |> get_user!()
    |> get_user_preference(key, default)
  end

  @doc """
  Returns both platform roles and context roles for a specific user id
  """
  def user_roles(user_id) do
    from(user in Oli.Accounts.User,
      where: user.id == ^user_id,
      left_join: enrollments in assoc(user, :enrollments),
      left_join: platform_roles in assoc(user, :platform_roles),
      left_join: context_roles in assoc(enrollments, :context_roles),
      select: [platform_roles, context_roles]
    )
    |> Repo.all()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.filter(& &1)
  end

  defp get_preference(preferences, key, default) do
    preferences
    |> Map.get(key, default)
    |> value_or(default)
  end

  @doc """
  Set's an author preference to the provided value at a given key

  See AuthorPreferences for available key options
  """
  def set_author_preference(author_id, key, value) when is_integer(author_id) do
    author_id
    |> get_author!()
    |> set_author_preference(key, value)
  end

  def set_author_preference(%Author{preferences: preferences} = author, key, value) do
    updated_preferences =
      preferences
      |> value_or(%AuthorPreferences{})
      |> Map.put(key, value)
      |> Map.from_struct()

    update_author(author, %{preferences: updated_preferences})
  end

  @doc """
  Set's an user preference to the provided value at a given key

  See UserPreferences for available key options
  """
  def set_user_preference(user_id, key, value) when is_integer(user_id) do
    user_id
    |> get_user!()
    |> set_user_preference(key, value)
  end

  def set_user_preference(%User{preferences: preferences} = user, key, value) do
    updated_preferences =
      preferences
      |> value_or(%UserPreferences{})
      |> Map.put(key, value)
      |> Map.from_struct()

    update_user(user, %{preferences: updated_preferences})
  end

  def can_access?(author, project) do
    if has_admin_role?(author, :content_admin) do
      # Admin authors have access to every project
      true
    else
      # querying join table rather than author's project associations list
      # in case the author has many projects
      Repo.one(
        from(assoc in "authors_projects",
          where:
            assoc.author_id == ^author.id and
              assoc.project_id == ^project.id,
          select: count(assoc)
        )
      ) != 0
    end
  end

  def can_access_via_slug?(author, project_slug) do
    if has_admin_role?(author, :content_admin) do
      # Admin authors have access to every project
      true
    else
      # querying join table rather than author's project associations list
      # in case the author has many projects
      Repo.one(
        from(assoc in "authors_projects",
          join: p in "projects",
          on: assoc.project_id == p.id,
          where:
            assoc.author_id == ^author.id and
              p.slug == ^project_slug,
          select: count(assoc)
        )
      ) != 0
    end
  end

  def project_author_count(project) do
    Repo.one(
      from(assoc in "authors_projects",
        join: author in Author,
        on: assoc.author_id == author.id,
        where:
          assoc.project_id in ^project.id and
            (is_nil(author.invitation_token) or not is_nil(author.invitation_accepted_at)),
        select: count(author)
      )
    )
  end

  def authors_projects(project_ids) when is_list(project_ids) do
    Repo.all(
      from(ap in AuthorProject,
        join: author in Author,
        on: ap.author_id == author.id,
        join: project in Project,
        on: ap.project_id == project.id,
        where: ap.project_id in ^project_ids,
        select: %{
          author: author,
          author_project_status: ap.status,
          project_slug: project.slug
        }
      )
    )
  end

  def authors_projects(project), do: authors_projects([project.id])

  @doc """
  Get all the communities for which the author is an admin.

  ## Examples

      iex> list_admin_communities(1)
      {:ok, [%Community{}, ...]}

      iex> list_admin_communities(123)
      {:ok, []}
  """
  def list_admin_communities(author_id) do
    Repo.all(
      from(
        community_account in CommunityAccount,
        join: community in assoc(community_account, :community),
        where: community_account.author_id == ^author_id and community_account.is_admin == true,
        select: community
      )
    )
  end

  @doc """
  Finds or creates an author and user logged in via sso, adds the user as a member of the given community
  and links both user and author.

  ## Examples

      iex> setup_sso_author(fields, community_id)
      {:ok, %Author{}}    -> # Inserted or updated with success
      {:error, changeset}         -> # Something went wrong

  """
  def setup_sso_author(fields, community_id) do
    res =
      Multi.new()
      |> Multi.run(:user, &create_sso_user(&1, &2, fields))
      |> Multi.run(:community_account, &create_community_account(&1, &2, community_id))
      |> Multi.run(:author, &create_sso_author(&1, &2, fields))
      |> Multi.run(:linked_user, &link_user_with_author(&1, &2))
      |> Repo.transaction()

    case res do
      {:ok, %{author: author}} ->
        {:ok, author}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Inserts or updates a user logged in via SSO, and adds the user as a member of the given community.

  ## Examples

      iex> setup_sso_user(fields, community_id)
      {:ok, %User{}, nil}          # Inserted or updated successfully, no author linked

      iex> setup_sso_user(fields, community_id)
      {:error, changeset}          # Something went wrong

  """
  def setup_sso_user(fields, community_id) do
    res =
      Multi.new()
      |> Multi.run(:user, &create_sso_user(&1, &2, fields))
      |> Multi.run(:community_account, &create_community_account(&1, &2, community_id))
      |> Multi.run(:author, &get_or_create_author(&1, &2, fields))
      |> Repo.transaction()

    case res do
      {:ok, %{user: user, author: author}} ->
        {:ok, Repo.reload(user), author}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp create_sso_user(_repo, _changes, fields) do
    insert_or_update_sso_user(%{
      sub: Map.get(fields, "sub"),
      preferred_username: Map.get(fields, "cognito:username"),
      email: Map.get(fields, "email"),
      name: Map.get(fields, "name"),
      can_create_sections: true
    })
  end

  defp get_or_create_author(_repo, %{user: %{author_id: nil} = user}, fields) do
    email = Map.get(fields, "email")
    name = Map.get(fields, "name")

    %Author{}
    |> Author.sso_changeset(%{name: name, email: email})
    |> Repo.insert()
    |> case do
      {:ok, author} = result ->
        case link_user_author_account(user, author) do
          {:ok, _user} ->
            result

          error ->
            error
        end

      error ->
        error
    end
  end

  defp get_or_create_author(_repo, %{user: %{author_id: author_id} = _user}, _fields) do
    {:ok, get_author(author_id)}
  end

  defp create_sso_author(_repo, _changes, fields) do
    email = Map.get(fields, "email")
    name = Map.get(fields, "name")

    case get_author_by_email(email) do
      nil ->
        %Author{}
        |> Author.noauth_changeset(%{name: name, email: email})
        |> Repo.insert()

      author ->
        {:ok, author}
    end
  end

  defp link_user_with_author(_repo, %{user: user, author: nil}), do: {:ok, user}

  defp link_user_with_author(_repo, %{user: user, author: author}),
    do: link_user_author_account(user, author)

  defp create_community_account(_repo, %{user: %User{id: user_id}}, community_id) do
    Groups.find_or_create_community_user_account(user_id, community_id)
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_independent_user_by_email("foo@example.com")
      %User{}

      iex> get_independent_user_by_email("unknown@example.com")
      nil

  """
  def get_independent_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email, independent_learner: true)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def get_user_by_email_and_password(_email, _password), do: nil

  @doc """
  Gets an independent user by email and password.

  ## Examples
      iex> get_independent_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_independent_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_independent_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email, independent_learner: true)
    if User.valid_password?(user, password), do: user
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_independent_user(%{field: value})
      {:ok, %User{independent_learner: true, guest: false, ...}}

      iex> register_independent_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_independent_user(attrs) do
    %User{independent_learner: true, guest: false}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs,
      hash_password: false,
      validate_email: false
    )
  end

  ## Email invitations

  @doc """
  When a new user accepts an invitation to a section, the user -student or instructor- data is updated (password for intance)
  and the enrollment status is updated from `:pending_confirmation` to `:enrolled`.

  Since both operations are related, they are wrapped in a transaction.
  """
  def accept_user_invitation(user, enrollment, attrs \\ %{}) do
    Repo.transaction(fn ->
      user
      |> User.accept_invitation_changeset(attrs)
      |> Repo.update!()

      enrollment
      |> Enrollment.changeset(%{status: :enrolled})
      |> Repo.update!()
    end)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user details.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_details(user, attrs \\ %{}) do
    User.details_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_confirmation_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Adds a user password. Used for accounts initially created by a login provider. This function
  should only run when the user has no password set.

  ## Examples

      iex> create_user_password(user, %{password: ...})
      {:ok, %User{}}

      iex> create_user_password(user, %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_password(%{password_hash: nil} = user, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    query
    |> Repo.one()
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.email_confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  @doc """
  Confirms a user as an admin.
  """
  def admin_confirm_user(user) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Generates a reset password token for the given user which can be used to generate a reset password URL.
  """
  def generate_user_reset_password_token(user) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)

    encoded_token
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Gets the user by enrollment invitation token.

  ## Examples

      iex> get_user_by_enrollment_invitation_token("validtoken")
      %UserToken{}

      iex> get_user_by_enrollment_invitation_token("invalidtoken")
      nil

  """
  def get_user_token_by_enrollment_invitation_token(token) do
    with {:ok, query} <- UserToken.enrollment_invitation_token_query(token),
         %UserToken{} = user_token <- Repo.one(query) |> Repo.preload(:user) do
      user_token
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Locks a user account preventing them from logging in.
  """
  def lock_user(user) do
    user
    |> User.lock_account_changeset(true)
    |> Repo.update()
  end

  @doc """
  Unlocks a user account.
  """
  def unlock_user(user) do
    user
    |> User.lock_account_changeset(false)
    |> Repo.update()
  end

  @doc """
  Returns whether the user account is waiting for confirmation or not.

  ## Examples

      iex> user_confirmation_pending?(%{email_confirmed_at: nil})
      true

      iex> user_confirmation_pending?(%{email_confirmed_at: ~U[2022-01-11 16:54:00Z]})
      false
  """
  def user_confirmation_pending?(%{email_confirmed_at: nil}), do: true

  def user_confirmation_pending?(_user), do: false

  ## Author

  @doc """
  Gets an author by email.

  ## Examples

      iex> get_author_by_email("foo@example.com")
      %Author{}

      iex> get_author_by_email("unknown@example.com")
      nil

  """
  def get_author_by_email(email) when is_binary(email) do
    Repo.get_by(Author, email: email)
  end

  @doc """
  Gets a author by email and password.

  ## Examples

      iex> get_author_by_email_and_password("foo@example.com", "correct_password")
      %Author{}

      iex> get_author_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_author_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    author = Repo.get_by(Author, email: email)
    if Author.valid_password?(author, password), do: author
  end

  ## Author registration

  @doc """
  Registers a author.

  ## Examples

      iex> register_author(%{field: value})
      {:ok, %Author{}}

      iex> register_author(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_author(attrs) do
    %Author{}
    |> Author.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking author changes.

  ## Examples

      iex> change_author_registration(author)
      %Ecto.Changeset{data: %Author{}}

  """
  def change_author_registration(%Author{} = author, attrs \\ %{}) do
    Author.registration_changeset(author, attrs,
      hash_password: false,
      validate_email: false
    )
  end

  @doc """
  Updates the author data after the inviter user redeems the authoring invitation.
  """
  def accept_author_invitation(author, attrs \\ %{}) do
    author
    |> Author.accept_invitation_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  When a new collaborator accepts an invitation to a project, the author's data is updated (password for intance)
  and the author_project status is updated from `:pending_confirmation` to `:accepted`.

  Since both operations are related, they are wrapped in a transaction.
  """
  def accept_collaborator_invitation(author, author_project, attrs \\ %{}) do
    Repo.transaction(fn ->
      author
      |> Author.accept_invitation_changeset(attrs)
      |> Repo.update!()

      author_project
      |> AuthorProject.changeset(%{status: :accepted})
      |> Repo.update!()
    end)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the author details.

  ## Examples

      iex> change_author_details(author)
      %Ecto.Changeset{data: %Author{}}

  """
  def change_author_details(author, attrs \\ %{}) do
    Author.noauth_changeset(author, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the author email.

  ## Examples

      iex> change_author_email(author)
      %Ecto.Changeset{data: %Author{}}

  """
  def change_author_email(author, attrs \\ %{}) do
    Author.email_changeset(author, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_author_email(author, "valid password", %{email: ...})
      {:ok, %Author{}}

      iex> apply_author_email(author, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_author_email(author, password, attrs) do
    author
    |> Author.email_changeset(attrs)
    |> Author.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the author email using the given token.

  If the token matches, the author email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_author_email(author, token) do
    context = "change:#{author.email}"

    with {:ok, query} <- AuthorToken.verify_change_email_token_query(token, context),
         %AuthorToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(author_email_multi(author, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp author_email_multi(author, email, context) do
    changeset =
      author
      |> Author.email_changeset(%{email: email})
      |> Author.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:author, changeset)
    |> Ecto.Multi.delete_all(:tokens, AuthorToken.author_and_contexts_query(author, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given author.

  ## Examples

      iex> deliver_author_update_email_instructions(author, current_email, &url(~p"/authors/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_author_update_email_instructions(
        %Author{} = author,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, author_token} =
      AuthorToken.build_email_token(author, "change:#{current_email}")

    Repo.insert!(author_token)
    AuthorNotifier.deliver_confirmation_instructions(author, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the author password.

  ## Examples

      iex> change_author_password(author)
      %Ecto.Changeset{data: %Author{}}

  """
  def change_author_password(author, attrs \\ %{}) do
    Author.password_changeset(author, attrs, hash_password: false)
  end

  @doc """
  Updates the author password.

  ## Examples

      iex> update_author_password(author, "valid password", %{password: ...})
      {:ok, %Author{}}

      iex> update_author_password(author, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_author_password(author, password, attrs) do
    changeset =
      author
      |> Author.password_changeset(attrs)
      |> Author.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:author, changeset)
    |> Ecto.Multi.delete_all(:tokens, AuthorToken.author_and_contexts_query(author, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{author: author}} -> {:ok, author}
      {:error, :author, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates an author as an admin.
  """
  def admin_update_author(author, attrs \\ %{}) do
    author
    |> Author.noauth_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Adds an author password. Used for accounts initially created by a login provider. This function
  should only run when the author has no password set.

  ## Examples

      iex> create_author_password(author, %{password: ...})
      {:ok, %Author{}}

      iex> create_author_password(author, %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def create_author_password(%{password_hash: nil} = author, attrs) do
    changeset =
      author
      |> Author.password_changeset(attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:author, changeset)
    |> Ecto.Multi.delete_all(:tokens, AuthorToken.author_and_contexts_query(author, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{author: author}} -> {:ok, author}
      {:error, :author, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_author_session_token(author) do
    {token, author_token} = AuthorToken.build_session_token(author)
    Repo.insert!(author_token)
    token
  end

  @doc """
  Gets the author with the given signed token.
  """
  def get_author_by_session_token(token) do
    {:ok, query} = AuthorToken.verify_session_token_query(token)

    query
    |> Repo.one()
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_author_session_token(token) do
    Repo.delete_all(AuthorToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given author.

  ## Examples

      iex> deliver_author_confirmation_instructions(author, &url(~p"/authors/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_author_confirmation_instructions(confirmed_author, &url(~p"/authors/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_author_confirmation_instructions(%Author{} = author, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if author.email_confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, author_token} = AuthorToken.build_email_token(author, "confirm")
      Repo.insert!(author_token)

      AuthorNotifier.deliver_confirmation_instructions(
        author,
        confirmation_url_fun.(encoded_token)
      )
    end
  end

  @doc """
  Confirms a author by the given token.

  If the token matches, the author account is marked as confirmed
  and the token is deleted.
  """
  def confirm_author(token) do
    with {:ok, query} <- AuthorToken.verify_email_token_query(token, "confirm"),
         %Author{} = author <- Repo.one(query),
         {:ok, %{author: author}} <- Repo.transaction(confirm_author_multi(author)) do
      {:ok, author}
    else
      _ -> :error
    end
  end

  defp confirm_author_multi(author) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:author, Author.confirm_changeset(author))
    |> Ecto.Multi.delete_all(:tokens, AuthorToken.author_and_contexts_query(author, ["confirm"]))
  end

  @doc """
  Confirms an author as an admin.
  """
  def admin_confirm_author(author) do
    author
    |> Author.confirm_changeset()
    |> Repo.update()
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given author.

  ## Examples

      iex> deliver_author_reset_password_instructions(author, &url(~p"/authors/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_author_reset_password_instructions(%Author{} = author, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, author_token} = AuthorToken.build_email_token(author, "reset_password")
    Repo.insert!(author_token)

    AuthorNotifier.deliver_reset_password_instructions(
      author,
      reset_password_url_fun.(encoded_token)
    )
  end

  @doc """
  Generates a reset password token for the given user which can be used to generate a reset password URL.
  """
  def generate_author_reset_password_token(user) do
    {encoded_token, author_token} = AuthorToken.build_email_token(user, "reset_password")
    Repo.insert!(author_token)

    encoded_token
  end

  @doc """
  Gets the author by reset password token.

  ## Examples

      iex> get_author_by_reset_password_token("validtoken")
      %Author{}

      iex> get_author_by_reset_password_token("invalidtoken")
      nil

  """
  def get_author_by_reset_password_token(token) do
    with {:ok, query} <- AuthorToken.verify_email_token_query(token, "reset_password"),
         %Author{} = author <- Repo.one(query) do
      author
    else
      _ -> nil
    end
  end

  @doc """
  Gets the author token by invitation token.

  ## Examples

      iex> get_author_token_by_author_invitation_token("validtoken")
      %Author{}

      iex> get_author_token_by_author_invitation_token("invalidtoken")
      nil

  """
  def get_author_token_by_author_invitation_token(token) do
    with {:ok, query} <- AuthorToken.author_invitation_token_query(token),
         %AuthorToken{} = author_token <- Repo.one(query) |> Repo.preload(:author) do
      author_token
    else
      _ -> nil
    end
  end

  @doc """
  Gets the author by collaboration invitation token.

  ## Examples

      iex> get_author_token_by_collaboration_invitation_token("validtoken")
      %Author{}

      iex> get_author_token_by_collaboration_invitation_token("invalidtoken")
      nil

  """
  def get_author_token_by_collaboration_invitation_token(token) do
    with {:ok, query} <- AuthorToken.collaborator_invitation_token_query(token),
         %AuthorToken{} = author_token <- Repo.one(query) |> Repo.preload(:author) do
      author_token
    else
      _ -> nil
    end
  end

  @doc """
  Resets the author password.

  ## Examples

      iex> reset_author_password(author, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Author{}}

      iex> reset_author_password(author, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_author_password(author, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:author, Author.password_changeset(author, attrs))
    |> Ecto.Multi.delete_all(:tokens, AuthorToken.author_and_contexts_query(author, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{author: author}} -> {:ok, author}
      {:error, :author, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Locks an author account preventing them from logging in.
  """
  def lock_author(author) do
    author
    |> Author.lock_account_changeset(true)
    |> Repo.update()
  end

  @doc """
  Unlocks an author account.
  """
  def unlock_author(author) do
    author
    |> Author.lock_account_changeset(false)
    |> Repo.update()
  end

  @doc """
  Returns whether the author account is waiting for confirmation or not.

  ## Examples

      iex> author_confirmation_pending?(%{email_confirmed_at: nil})
      true

      iex> author_confirmation_pending?(%{email_confirmed_at: ~U[2022-01-11 16:54:00Z]})
      false
  """
  def author_confirmation_pending?(%{email_confirmed_at: nil}), do: true

  def author_confirmation_pending?(_user), do: false
end
