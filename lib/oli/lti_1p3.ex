defmodule Oli.Lti_1p3 do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Lti_1p3.Registration
  alias Oli.Lti_1p3.Deployment
  alias Oli.Lti_1p3.Jwk
  alias Oli.Lti_1p3.LtiParams

  def create_new_registration(attrs) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  def get_registration_by_kid(kid) do
    Repo.one(from r in Registration, where: r.kid == ^kid)
  end

  def get_registration_by_issuer(issuer) do
    Repo.one(from r in Registration, where: r.issuer == ^issuer)
  end

  def create_new_deployment(attrs) do
    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  def get_deployment(registration, deployment_id) do
    registration_id = registration.id
    Repo.one(from r in Deployment, where: r.registration_id == ^registration_id and r.deployment_id == ^deployment_id)
  end

  def create_new_jwk(attrs) do
    %Jwk{}
    |> Jwk.changeset(attrs)
    |> Repo.insert()
  end

  def get_active_jwk() do
    Repo.one(from k in Jwk, where: k.active == true)
  end

  def get_all_jwks() do
    Repo.all(from k in Jwk, where: k.active == true)
  end

  def get_ird_by_deployment_id(deployment_id) do
    Repo.one from institution in Oli.Institutions.Institution,
      join: registration in Registration, on: registration.institution_id == institution.id,
      join: deployment in Deployment, on: deployment.registration_id == registration.id,
      where: deployment.deployment_id == ^deployment_id,
      select: {institution, registration, deployment}
  end

  def get_registration_by_client_id(client_id) do
    Repo.one from r in Registration,
      where: r.client_id == ^client_id,
      select: r
  end

  @doc """
  Returns lti_1p3 deployment if a record matches deployment_id, or creates and returns a new deployment

  ## Examples

      iex> insert_or_update_lti_1p3_deployment(%{deployment_id: deployment_id})
      {:ok, %Oli.Lti_1p3.Deployment{}}    -> # Inserted or updated with success
      {:error, changeset}                 -> # Something went wrong

  """
  def insert_or_update_lti_1p3_deployment(%{deployment_id: deployment_id} = changes) do
    case Repo.get_by(Oli.Lti_1p3.Deployment, deployment_id: deployment_id) do
      nil -> %Oli.Lti_1p3.Deployment{}
      deployment -> deployment
    end
    |> Oli.Lti_1p3.Deployment.changeset(changes)
    |> Repo.insert_or_update
  end

  @doc """
  Caches LTI 1.3 params map using the given key. Assumes lti_params contains standard LTI fields
  including "exp" for expiration date
  ## Examples
      iex> cache_lti_params(key, lti_params)
      {:ok, %LtiParams{}}
      iex> create_nonce(key, bad_params)
      {:error, %Ecto.Changeset{}}
  """
  def cache_lti_params(key, lti_params) do
    exp = Timex.from_unix(lti_params["exp"])
    %LtiParams{}
    |> LtiParams.changeset(%{key: key, data: lti_params, exp: exp})
    |> Repo.insert()
  end

  @doc """
  Gets a user's cached lti_params from the database using the given key.
  Returns `nil` if the lti_params do not exist.
  ## Examples
      iex> fetch_lti_params("some-key")
      %LtiParams{}
      iex> fetch_lti_params("bad-key")
      nil
  """
  def fetch_lti_params(key), do: Repo.get_by(LtiParams, key: key)
end
