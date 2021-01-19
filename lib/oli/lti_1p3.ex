defmodule Oli.Lti_1p3 do
  import Ecto.Query, warn: false
  import Oli.Lti_1p3.Utils

  alias Oli.Repo
  alias Oli.Lti_1p3.Registration
  alias Oli.Lti_1p3.Deployment
  alias Oli.Lti_1p3.Jwk
  alias Oli.Lti_1p3.LtiParams

  @deployment_id_key "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

  def get_deployment_id_from_launch(lti_launch_params) do
    Map.get(lti_launch_params, @deployment_id_key)
  end

  def create_new_registration(attrs) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
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
    case Repo.all(from k in Jwk, where: k.active == true, order_by: [desc: k.id], limit: 1) do
      [head | _] -> head
      _ -> []
    end
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
      iex> cache_lti_params!(key, lti_params)
      %LtiParams{}
  """
  def cache_lti_params!(key, lti_params) do
    exp = Timex.from_unix(lti_params["exp"])

    case Repo.get_by(LtiParams, key: key) do
      nil  -> %LtiParams{}
      lti_params -> lti_params
    end
    |> LtiParams.changeset(%{key: key, data: lti_params, exp: exp})
    |> Repo.insert_or_update!()
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

  # TODO
  def authorize_redirect(conn, params) do

    IO.inspect params

    # registered ahead of time, loaded from lti_1p3_platform_instances
    key_set_url = "https://lti-ri.imsglobal.org/lti/tools/1234/.well-known/jwks.json"
    issuer = Oli.Utils.get_base_url()
    client_id = "10000000000001"
    deployment_id = "1"

    {:ok, jwt_string} = extract_param(conn, "state")
    {:ok, _conn, state_jwt} = validate_jwt_signature(conn, jwt_string, key_set_url)

    IO.inspect state_jwt, label: "state_jwt"



    # TODO: do some validation, validate redirect_uri, client_id, user's login_hint, etc...
    IO.puts("TODO: do some validation, validate redirect_uri, client_id, user's login_hint, etc...")



    active_jwk = get_active_jwk()

    IO.inspect active_jwk.pem, label: "pem"

    # signer = Joken.Signer.create("RS256", %{"pem" => pem})

    custom_header = %{"kid" => active_jwk.kid}
    signer = Joken.Signer.create("RS256", %{"pem" => active_jwk.pem}, custom_header)

    {:ok, claims} = Joken.Config.default_claims(iss: issuer, aud: client_id)
      |> Joken.generate_claims(%{
        "nonce" => UUID.uuid4(),
        "sub" => "test sub",
        "name" => "test name",
        "given_name" => "test given_name",
        "family_name" => "test family_name",
        "middle_name" => "test middle_name",

        # TODO: more claims data, e.g. test/support/lti_1p3_test_helpers.ex:104
      })

    IO.inspect claims, label: "claims"

    {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

    state = params["state"]
    redirect_uri = params["redirect_uri"]

    {:ok, redirect_uri, state, id_token}
  end

end
