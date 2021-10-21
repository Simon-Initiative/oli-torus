defmodule Oli.Accounts do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Accounts.{User, Author, SystemRole, UserBrowseOptions, AuthorBrowseOptions}

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
        dynamic(
          [s, _],
          ilike(s.name, ^"%#{options.text_search}%") or
            ilike(s.email, ^"%#{options.text_search}%") or
            ilike(s.given_name, ^"%#{options.text_search}%") or
            ilike(s.family_name, ^"%#{options.text_search}%") or
            ilike(s.name, ^"#{options.text_search}") or
            ilike(s.email, ^"#{options.text_search}") or
            ilike(s.given_name, ^"#{options.text_search}") or
            ilike(s.family_name, ^"#{options.text_search}")
        )
      end

    query =
      User
      |> join(:left, [u], e in "enrollments", on: u.id == e.user_id)
      |> where(^filter_by_text)
      |> where(^filter_by_guest)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(:author)
      |> group_by([u, _], u.id)
      |> select_merge([u, e], %{
        enrollments_count: count(e.id),
        total_count: fragment("count(*) OVER()")
      })

    query =
      case field do
        :enrollments_count -> order_by(query, [_, e], {^direction, count(e.id)})
        _ -> order_by(query, [p, _], {^direction, field(p, ^field)})
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
        dynamic(
          [s, _],
          ilike(s.name, ^"#{options.text_search}") or
            ilike(s.given_name, ^"#{options.text_search}") or
            ilike(s.family_name, ^"#{options.text_search}") or
            ilike(s.name, ^"%#{options.text_search}%") or
            ilike(s.given_name, ^"%#{options.text_search}%") or
            ilike(s.family_name, ^"%#{options.text_search}%")
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
  Returns user details if a record matches sub, or creates and returns a new user

  ## Examples

      iex> insert_or_update_user(%{field: value})
      {:ok, %User{}}    -> # Inserted or updated with success
      {:error, changeset}         -> # Something went wrong

  """
  def insert_or_update_user(%{sub: sub} = changes) do
    case Repo.get_by(User, sub: sub) do
      nil -> %User{}
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
  Searches for a list of authors with an email matching a wildcard pattern
  """
  def search_authors_matching(query) do
    q = query
    q = "%" <> q <> "%"

    Repo.all(
      from(author in Author,
        where: ilike(author.email, ^q)
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
end
