defmodule Oli.Institutions do
  @moduledoc """
  The Institutions context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Institutions.Institution
  alias Oli.Institutions.PendingRegistration
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
      where: registration.issuer == ^ issuer and registration.client_id == ^client_id,
      select: registration
  end

  @doc """
  Returns the list of pending_registrations.
  ## Examples
      iex> list_pending_registrations()
      [%PendingRegistration{}, ...]
  """
  def list_pending_registrations do
    Repo.all(PendingRegistration)
  end

  @doc """
  Returns the count of pending_registrations.
  ## Examples
      iex> count_pending_registrations()
      123
  """
  def count_pending_registrations do
    Repo.aggregate(PendingRegistration, :count)
  end

  @doc """
  Gets a single pending_registration.
  Raises `Ecto.NoResultsError` if the PendingRegistration does not exist.
  ## Examples
      iex> get_pending_registration!(123)
      %PendingRegistration{}
      iex> get_pending_registration!(456)
      ** (Ecto.NoResultsError)
  """
  def get_pending_registration!(id), do: Repo.get!(PendingRegistration, id)

  @doc """
  Gets a single pending_registration by the issuer and client_id.
  Returns nil if the PendingRegistration does not exist.
  ## Examples
      iex> get_pending_registration_by_issuer_client_id(123)
      %PendingRegistration{}
      iex> get_pending_registration_by_issuer_client_id(456)
      nil
  """
  def get_pending_registration_by_issuer_client_id(issuer, client_id) do
    Repo.one from pr in PendingRegistration,
      where: pr.issuer == ^ issuer and pr.client_id == ^client_id,
      select: pr
  end

  @doc """
  Creates a pending_registration.
  ## Examples
      iex> create_pending_registration(%{field: value})
      {:ok, %PendingRegistration{}}
      iex> create_pending_registration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_pending_registration(attrs \\ %{}) do
    %PendingRegistration{}
    |> PendingRegistration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a pending_registration.
  ## Examples
      iex> update_pending_registration(pending_registration, %{field: new_value})
      {:ok, %PendingRegistration{}}
      iex> update_pending_registration(pending_registration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_pending_registration(%PendingRegistration{} = pending_registration, attrs) do
    pending_registration
    |> PendingRegistration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a pending_registration.
  ## Examples
      iex> delete_pending_registration(pending_registration)
      {:ok, %PendingRegistration{}}
      iex> delete_pending_registration(pending_registration)
      {:error, %Ecto.Changeset{}}
  """
  def delete_pending_registration(%PendingRegistration{} = pending_registration) do
    Repo.delete(pending_registration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking pending_registration changes.
  ## Examples
      iex> change_pending_registration(pending_registration)
      %Ecto.Changeset{source: %PendingRegistration{}}
  """
  def change_pending_registration(%PendingRegistration{} = pending_registration) do
    PendingRegistration.changeset(pending_registration, %{})
  end

  @doc false
  # Returns the institution that has a similar (normalized) url. If no institutions a similar url
  # exist, then a new one is created. If more than one institution with a similar url exist, then
  # the first institution in the result is returned.
  #
  # ## Examples
  #     iex> find_or_create_institution_by_normalized_url(institution_attrs)
  #     {:ok, %Institution{}}
  def find_or_create_institution_by_normalized_url(institution_attrs) do
    normalized_url = institution_attrs[:institution_url]
      |> String.replace(~r/^https?\:\/\//i, "")
      |> String.replace_trailing("/", "")

    case Repo.all(from i in Institution, where: like(i.institution_url, ^normalized_url), select: i) do
      [] -> create_institution(institution_attrs)
      [institution] -> {:ok, institution}
      [institution | _] -> {:ok, institution}
    end
  end

  @doc """
  Approves a pending registration request. If successful, a new registration will be created and attached
  to a new or existing institution if one with a similar url already exists.
  The operation guarantees all actions or none are performed.
  ## Examples
      iex> approve_pending_registration(pending_registration)
      {:ok, {%Institution{}, %Registration{}}}
      iex> approve_pending_registration(pending_registration)
      {:error, reason}
  """
  def approve_pending_registration(%PendingRegistration{} = pending_registration) do
    Repo.transaction(fn ->
      with {:ok, institution} <- find_or_create_institution_by_normalized_url(PendingRegistration.institution_attrs(pending_registration)),
        active_jwk = Oli.Lti_1p3.get_active_jwk(),
        registration_attrs = Map.merge(PendingRegistration.registration_attrs(pending_registration), %{institution_id: institution.id, tool_jwk_id: active_jwk.id}),
        {:ok, registration} <- create_registration(registration_attrs),
        {:ok, _pending_registration} <- delete_pending_registration(pending_registration)
      do
        {institution, registration}
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Searches for a list of Institution with an name matching a wildcard pattern
  """
  def search_authors_matching(query) do
    q = query
    q = "%" <> q <> "%"
    Repo.all from i in Institution,
             where: ilike(i.name, ^q)
  end

end
