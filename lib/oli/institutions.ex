defmodule Oli.Institutions do
  @moduledoc """
  The Institutions context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Institutions.Institution
  alias Oli.Lti_1p3.Registration
  alias Oli.Lti_1p3.Deployment

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
  def get_institution!(id), do: Repo.get!(Institution, id) |> Repo.preload([registrations: [:deployments]])

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

  @doc """
  Returns the list of registrations.

  ## Examples

      iex> list_registrations()
      [%Registration{}, ...]

  """
  def list_registrations do
    Repo.all(Registration)
  end

  @doc """
  Gets a single registration.

  Raises if the Registration does not exist.

  ## Examples

      iex> get_registration!(123)
      %Registration{}

  """
  def get_registration!(id), do: Repo.get!(Registration, id) |> Repo.preload([:deployments])

  @doc """
  Creates a registration.

  ## Examples

      iex> create_registration(%{field: value})
      {:ok, %Registration{}}

      iex> create_registration(%{field: bad_value})
      {:error, ...}

  """
  def create_registration(attrs \\ %{}) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a registration.

  ## Examples

      iex> update_registration(registration, %{field: new_value})
      {:ok, %Registration{}}

      iex> update_registration(registration, %{field: bad_value})
      {:error, ...}

  """
  def update_registration(%Registration{} = registration, attrs) do
    registration
    |> Registration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Registration.

  ## Examples

      iex> delete_registration(registration)
      {:ok, %Registration{}}

      iex> delete_registration(registration)
      {:error, ...}

  """
  def delete_registration(%Registration{} = registration) do
    Repo.delete(registration)
  end

  @doc """
  Returns a data structure for tracking registration changes.

  ## Examples

      iex> change_registration(registration)
      %Todo{...}

  """
  def change_registration(%Registration{} = registration, _attrs \\ %{}) do
    Registration.changeset(registration, %{})
  end

  @doc """
  Returns the list of deployments.

  ## Examples

      iex> list_deployments()
      [%Deployment{}, ...]

  """
  def list_deployments do
    Repo.all(Deployment)
  end

  @doc """
  Gets a single deployment.

  Raises if the Deployment does not exist.

  ## Examples

      iex> get_deployment!(123)
      %Deployment{}

  """
  def get_deployment!(id), do: Repo.get!(Deployment, id)

  @doc """
  Creates a deployment.

  ## Examples

      iex> create_deployment(%{field: value})
      {:ok, %Deployment{}}

      iex> create_deployment(%{field: bad_value})
      {:error, ...}

  """
  def create_deployment(attrs \\ %{}) do
    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a deployment.

  ## Examples

      iex> update_deployment(deployment, %{field: new_value})
      {:ok, %Deployment{}}

      iex> update_deployment(deployment, %{field: bad_value})
      {:error, ...}

  """
  def update_deployment(%Deployment{} = deployment, attrs) do
    deployment
    |> Deployment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Deployment.

  ## Examples

      iex> delete_deployment(deployment)
      {:ok, %Deployment{}}

      iex> delete_deployment(deployment)
      {:error, ...}

  """
  def delete_deployment(%Deployment{} = deployment) do
    Repo.delete(deployment)
  end

  @doc """
  Returns a data structure for tracking deployment changes.

  ## Examples

      iex> change_deployment(deployment)
      %Todo{...}

  """
  def change_deployment(%Deployment{} = deployment, _attrs \\ %{}) do
    Deployment.changeset(deployment, %{})
  end

  def get_registration_by_issuer_client_id(issuer, client_id) do
    Repo.one from registration in Registration,
      join: institution in Institution, on: registration.institution_id == institution.id,
      where: registration.issuer == ^ issuer and registration.client_id == ^client_id and not is_nil(institution.approved_at),
      select: registration
  end

  def get_pending_registration_by_issuer_client_id(issuer, client_id) do
    Repo.one from registration in Registration,
      join: institution in Institution, on: registration.institution_id == institution.id,
      where: registration.issuer == ^ issuer and registration.client_id == ^client_id and is_nil(institution.approved_at),
      select: registration
  end

end
