defmodule Oli.Accounts do
  import Ecto.Query, warn: false
  import Oli.Utils, only: [value_or: 2]

  alias Ecto.Multi

  alias Oli.Accounts.{
    User,
    Author,
    SystemRole,
    UserBrowseOptions,
    AuthorBrowseOptions,
    AuthorPreferences
  }

  alias Oli.Groups
  alias Oli.Groups.CommunityAccount
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias PowEmailConfirmation.Ecto.Context, as: EmailConfirmationContext

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
  Creates a user.
  ## Examples
      iex> create_user(%{field: value})
      {:ok, %User{}}
      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
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
  Updates user details if a record matches sub, otherwise creates a new user

  ## Examples

      iex> insert_or_update_lms_user(%{sub, "123", field: value})
      {:ok, %User{}}    -> # Inserted or updated with success
      {:error, changeset}         -> # Something went wrong

  """
  def insert_or_update_lms_user(%{sub: sub} = changes) do
    case Repo.get_by(User, sub: sub) do
      nil -> %User{sub: sub, independent_learner: false}
      user -> user
    end
    |> User.noauth_changeset(changes)
    |> Repo.insert_or_update()
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

  @doc """
  Returns true if a user is signed in
  """
  def user_signed_in?(conn) do
    conn.assigns[:current_user]
  end

  @doc """
  Returns true if a user is signed in as guest
  """
  def user_is_guest?(conn) do
    case conn.assigns[:current_user] do
      %{guest: true} ->
        true

      _ ->
        false
    end
  end

  @doc """
  Returns true if a user is signed in as an independent learner
  """
  def user_is_independent_learner?(current_user) do
    case current_user do
      %{independent_learner: true} ->
        true

      _ ->
        false
    end
  end

  @doc """
  Returns true if an author is an administrator.
  """
  def is_admin?(nil), do: false

  def is_admin?(%Author{system_role_id: system_role_id}) do
    SystemRole.role_id().admin == system_role_id
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
  Creates and returns a new author
  ## Examples
      iex> create_author(%{field: value})
      {:ok, %Author{}}
  """
  def create_author(params \\ %{}) do
    %Author{}
    |> Author.changeset(params)
    |> Repo.insert()
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
  Gets a single author with the given email
  """
  def get_author_by_email(email) do
    Repo.get_by(Author, email: email)
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
    case Repo.get_by(Author, email: email) do
      nil -> false
      _author -> true
    end
  end

  @doc """
  Returns true if a author is signed in
  """
  def author_signed_in?(conn) do
    conn.assigns[:current_author]
  end

  @doc """
  Returns an author preference using the key provided. If the preference isn't set or
  the author preferences have not been created yet, the default value will be returned.

  Accepts and Author struct or author id. If an id is given, the latest author record
  will be queried from the database. Otherwise, the preferences in the Author struct
  is used.

  See AuthorPreferences for available key options
  """
  def get_author_preference(author, key, default \\ nil)

  def get_author_preference(%Author{preferences: preferences}, key, default) do
    preferences
    |> value_or(%AuthorPreferences{})
    |> Map.get(key, default)
    |> value_or(default)
  end

  def get_author_preference(author_id, key, default) when is_integer(author_id) do
    author = get_author!(author_id)

    get_author_preference(author, key, default)
  end

  @doc """
  Set's an author preference to the provided value at a given key

  See AuthorPreferences for available key options
  """
  def set_author_preference(%Author{id: author_id}, key, value),
    do: set_author_preference(author_id, key, value)

  def set_author_preference(author_id, key, value) do
    author = get_author!(author_id)

    updated_preferences =
      author.preferences
      |> value_or(%AuthorPreferences{})
      |> Map.put(key, value)
      |> Map.from_struct()

    update_author(author, %{preferences: updated_preferences})
  end

  def can_access?(author, project) do
    admin_role_id = SystemRole.role_id().admin

    case author do
      # Admin authors have access to every project
      %{system_role_id: ^admin_role_id} ->
        true

      # querying join table rather than author's project associations list
      # in case the author has many projects
      _ ->
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
    admin_role_id = SystemRole.role_id().admin

    case author do
      # Admin authors have access to every project
      %{system_role_id: ^admin_role_id} ->
        true

      # querying join table rather than author's project associations list
      # in case the author has many projects
      _ ->
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

  def project_authors(project_ids) when is_list(project_ids) do
    Repo.all(
      from(assoc in "authors_projects",
        join: author in Author,
        on: assoc.author_id == author.id,
        where:
          assoc.project_id in ^project_ids and
            (is_nil(author.invitation_token) or not is_nil(author.invitation_accepted_at)),
        select: [author, assoc.project_id]
      )
    )
  end

  def project_authors(project) do
    Repo.all(
      from(assoc in "authors_projects",
        join: author in Author,
        on: assoc.author_id == author.id,
        where:
          assoc.project_id == ^project.id and
            (is_nil(author.invitation_token) or not is_nil(author.invitation_accepted_at)),
        select: author
      )
    )
  end

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
  Returns whether the user account is waiting for confirmation or not.

  ## Examples

      iex> user_confirmation_pending?(%{email_confirmation_token: "token", email_confirmed_at: nil})
      true

      iex> user_confirmation_pending?(%{email_confirmation_token: nil, email_confirmed_at: ~U[2022-01-11 16:54:00Z]})
      false
  """
  def user_confirmation_pending?(user) do
    EmailConfirmationContext.current_email_unconfirmed?(user, []) or
      EmailConfirmationContext.pending_email_change?(user, [])
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
  Inserts or updates an user logged in via sso, and adds the user as a member of the given community.

  ## Examples

      iex> setup_sso_user(fields, community_id)
      {:ok, %User{}}    -> # Inserted or updated with success
      {:error, changeset}         -> # Something went wrong

  """
  def setup_sso_user(fields, community_id) do
    res =
      Multi.new()
      |> Multi.run(:user, &create_sso_user(&1, &2, fields))
      |> Multi.run(:community_account, &create_community_account(&1, &2, community_id))
      |> Repo.transaction()

    case res do
      {:ok, %{user: user}} ->
        {:ok, user}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp create_sso_user(_repo, _changes, fields) do
    insert_or_update_lms_user(%{
      sub: Map.get(fields, "sub"),
      preferred_username: Map.get(fields, "cognito:username"),
      email: Map.get(fields, "email"),
      name: Map.get(fields, "name"),
      can_create_sections: true
    })
  end

  defp create_sso_author(_repo, _changes, fields) do
    email = Map.get(fields, "email")
    username = Map.get(fields, "cognito:username")

    case get_author_by_email(email) do
      nil ->
        %Author{}
        |> Author.noauth_changeset(%{name: username, email: email})
        |> Repo.insert()

      author ->
        {:ok, author}
    end
  end

  defp link_user_with_author(_repo, %{user: user, author: author}) do
    link_user_author_account(user, author)
  end

  defp create_community_account(_repo, %{user: %User{id: user_id}}, community_id) do
    Groups.find_or_create_community_user_account(user_id, community_id)
  end
end
