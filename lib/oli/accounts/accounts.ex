defmodule Oli.Accounts do

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Accounts.{User, Author, Institution, LtiToolConsumer}

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @doc """
  Links a User to Author account
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

  @doc """
  Returns an author if one matches given email, or creates and returns a new author
  """
  def insert_or_update_author(%{ email: email } = changes) do
    case Repo.get_by(Author, email: email) do
      nil -> %Author{}
      author -> author
    end
    |> Author.changeset(changes)
    |> Repo.insert_or_update
  end

  def create_author(params \\ %{}, opts \\ []) do
    %Author{}
    |> Author.changeset(params, opts)
    |> Repo.insert()
  end

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

  def list_institutions do
    Repo.all(Institution)
  end

  def get_institution!(id), do: Repo.get!(Institution, id)

  def create_institution(attrs \\ %{}) do
    %Institution{}
    |> Institution.changeset(attrs)
    |> Repo.insert()
  end

  def update_institution(%Institution{} = institution, attrs) do
    institution
    |> Institution.changeset(attrs)
    |> Repo.update()
  end

  def delete_institution(%Institution{} = institution) do
    Repo.delete(institution)
  end

  def change_institution(%Institution{} = institution) do
    Institution.changeset(institution, %{})
  end

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
