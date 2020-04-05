defmodule Oli.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
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
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
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
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @doc """
  Links a User to Author account

  ## Examples
      iex> link_user_author_account(user, author)
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def link_user_author_account(nil, _author), do: throw "No current_user to link to author. This function should only be called in an LTI context"
  def link_user_author_account(user, author) do
    update_user(user, %{ author_id: author.id})
  end

  @doc """
  Returns true if a author is signed in
  """
  def user_signed_in?(conn) do
    conn.assigns[:current_user]
  end

  alias Oli.Accounts.Author

  @doc """
  Returns an author if one matches given email, or creates and returns a new author

  ## Examples

      iex> insert_or_update_author(%{field: value})
      {:ok, %Author{}}

  """
  def insert_or_update_author(%{ email: email } = changes) do
    case Repo.get_by(Author, email: email) do
      nil -> %Author{}
      author -> author
    end
    |> Author.changeset(changes)
    |> Repo.insert_or_update
  end

  @doc """
  Creates and returns a new author

  ## Examples

      iex> create_author(%{field: value})
      {:ok, %Author{}}

  """
  def create_author(params \\ %{}, opts \\ []) do
    %Author{}
    |> Author.changeset(params, opts)
    |> Repo.insert()
  end

  @doc """
  Gets a single author with the given email
  """
  def get_author_by_email(email) do
    Repo.get_by(Author, email: email)
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
  Authorizes a author with the given email and passord
  """
  def authorize_author(author_email, password) do
    Repo.get_by(Author, email: author_email)
      |> authorize(password)
  end

  defp authorize(nil, _password), do: {:error, "Invalid authorname or password"}
  defp authorize(author, password) do
    Bcrypt.check_pass(author, password, hash_key: :password_hash)
    |> resolve_authorization(author)
  end

  defp resolve_authorization({:error, _reason}, _author), do: {:error, "Invalid authorname or password"}
  defp resolve_authorization({:ok, author}, _author), do: {:ok, author}

  def can_access?(author, project) do
    # querying join table rather than author's project associations list
    # in case the author has many projects
    Repo.one(
      from assoc in "authors_projects",
        where: assoc.author_id == ^author.id and
        assoc.project_id == ^project.id,
        select: count(assoc)) != 0
  end

  def project_author_count(project) do
    Repo.one(
      from assoc in "authors_projects",
        where: assoc.project_id == ^project.id,
        select: count(assoc))
  end

  def project_authors(project) do
    Repo.all(from assoc in "authors_projects",
      where: assoc.project_id == ^project.id,
      join: author in Author,
      on: assoc.author_id == author.id,
      select: author)
  end

  alias Oli.Accounts.Institution

  @doc """
  Returns the list of institutions.

  ## Examples

      iex> list_institutions()
      [%Institution{}, ...]

  """
  def list_institutions do
    Repo.all(Institution)
  end

  @doc """
  Gets a single institution.

  Raises `Ecto.NoResultsError` if the Institution does not exist.

  ## Examples

      iex> get_institution!(123)
      %Institution{}

      iex> get_institution!(456)
      ** (Ecto.NoResultsError)

  """
  def get_institution!(id), do: Repo.get!(Institution, id)

  @doc """
  Creates a institution.

  ## Examples

      iex> create_institution(%{field: value})
      {:ok, %Institution{}}

      iex> create_institution(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_institution(attrs \\ %{}) do
    %Institution{}
    |> Institution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a institution.

  ## Examples

      iex> update_institution(institution, %{field: new_value})
      {:ok, %Institution{}}

      iex> update_institution(institution, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_institution(%Institution{} = institution, attrs) do
    institution
    |> Institution.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a institution.

  ## Examples

      iex> delete_institution(institution)
      {:ok, %Institution{}}

      iex> delete_institution(institution)
      {:error, %Ecto.Changeset{}}

  """
  def delete_institution(%Institution{} = institution) do
    Repo.delete(institution)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking institution changes.

  ## Examples

      iex> change_institution(institution)
      %Ecto.Changeset{source: %Institution{}}

  """
  def change_institution(%Institution{} = institution) do
    Institution.changeset(institution, %{})
  end


  alias Oli.Accounts.User

  @doc """
  Returns lti author details if a record matches author_id, or creates and returns a new lti author details

  ## Examples

      iex> insert_or_update_user(%{field: value})
      {:ok, %User{}}    -> # Inserted or updated with success
      {:error, changeset}         -> # Something went wrong

  """
  def insert_or_update_user(%{ user_id: user_id } = changes) do
    case Repo.get_by(User, user_id: user_id) do
      nil -> %User{}
      user -> user
    end
    |> User.changeset(changes)
    |> Repo.insert_or_update
  end


  alias Oli.Accounts.LtiToolConsumer

  @doc """
  Returns lti tool consumer if a record matches instance_guid, or creates and returns a new lti tool consumer

  ## Examples

      iex> insert_or_update_lti_tool_consumer(%{field: value})
      {:ok, %LtiToolConsumer{}}    -> # Inserted or updated with success
      {:error, changeset}          -> # Something went wrong

  """
  def insert_or_update_lti_tool_consumer(%{ instance_guid: instance_guid } = changes) do
    case Repo.get_by(LtiToolConsumer, instance_guid: instance_guid) do
      nil -> %LtiToolConsumer{}
      lti_tool_consumer -> lti_tool_consumer
    end
    |> LtiToolConsumer.changeset(changes)
    |> Repo.insert_or_update
  end
end
