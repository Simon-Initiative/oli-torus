defmodule Oli.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Accounts.User

  @doc """
  Returns an user if one matches given email, or creates an returns a new user

  ## Examples

      iex> insert_or_update_user(%{field: value})
      {:ok, %User{}}

  """
  def insert_or_update_user(changeset) do
    case Repo.get_by(User, email: changeset.changes.email) do
      nil ->
        Repo.insert(changeset)
      user ->
        {:ok, user}
    end
  end

  @doc """
  Creates an returns a new user

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

  """
  def create_user(params \\ %{}) do
    %User{}
    |> User.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Gets a single user with the given email
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Returns true if a user is signed in
  """
  def signed_in?(conn) do
    conn.assigns[:user]
  end

  @doc """
  Authorizes a user with the given email and passord
  """
  def authorize_user(user_email, password) do
    Repo.get_by(User, email: user_email)
      |> authorize(password)
  end

  defp authorize(nil, _password), do: {:error, "Invalid username or password"}
  defp authorize(user, password) do
    Bcrypt.check_pass(user, password, hash_key: :password_hash)
    |> resolve_authorization(user)
  end

  defp resolve_authorization({:error, _reason}, _user), do: {:error, "Invalid username or password"}
  defp resolve_authorization({:ok, user}, _user), do: {:ok, user}

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
end
