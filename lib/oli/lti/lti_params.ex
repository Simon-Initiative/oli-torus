defmodule Oli.Lti.LtiParams do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Lti.LtiParams

  schema "lti_1p3_params" do
    field(:issuer, :string)
    field(:client_id, :string)
    field(:deployment_id, :string)
    field(:context_id, :string)
    field(:sub, :string)
    field(:params, :map)
    field(:exp, :utc_datetime)

    belongs_to(:user, Oli.Lti.Tool.Registration)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(nonce, attrs) do
    nonce
    |> cast(attrs, [
      :issuer,
      :client_id,
      :deployment_id,
      :context_id,
      :sub,
      :params,
      :exp,
      :user_id
    ])
    |> validate_required([
      :issuer,
      :client_id,
      :deployment_id,
      :context_id,
      :sub,
      :params,
      :exp
    ])
    |> unique_constraint([:issuer, :client_id, :deployment_id, :context_id, :sub])
  end

  @doc """
  Creates or updates a users lti params for the given issuer, client_id, deployment_id, context_id and sub.

  If a user_id is given then the lti params will be created/update with the given id. If the user_id is omitted
  or nil, then the user id will remain the same (or nil if lti params are being created). Once created, only the
  params (JSON lti params), exp (expiration) and associated user_id can be updated. A user_id can not be set back
  to nil once it has been set.
  """
  def create_or_update_lti_params(params, user_id \\ nil) do
    issuer = params["iss"]
    client_id = peek_client_id(params)
    sub = params["sub"]
    deployment_id = params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
    context_id = params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"]
    exp = Timex.from_unix(params["exp"])

    case Repo.get_by(LtiParams,
           issuer: issuer,
           client_id: client_id,
           deployment_id: deployment_id,
           context_id: context_id,
           sub: sub
         ) do
      nil ->
        %LtiParams{}
        |> LtiParams.changeset(%{
          issuer: issuer,
          client_id: client_id,
          deployment_id: deployment_id,
          context_id: context_id,
          sub: sub,
          user_id: user_id,
          params: params,
          exp: exp
        })

      fetched_params ->
        case user_id do
          nil ->
            fetched_params
            |> LtiParams.changeset(%{
              params: params,
              exp: exp
            })

          user_id ->
            fetched_params
            |> LtiParams.changeset(%{
              user_id: user_id,
              params: params,
              exp: exp
            })
        end
    end
    |> Repo.insert_or_update()
  end

  @doc """
  Returns lti params for the given id
  """
  def get_lti_params(id) do
    Repo.get(LtiParams, id)
  end

  @doc """
  Returns the latest lti params for the given user
  """
  def get_latest_user_lti_params(user_id) do
    # LTI Params record is updated on every launch. We can use the updated_at field to get the
    # latest record for the user.
    from(p in LtiParams,
      where: p.user_id == ^user_id,
      order_by: [desc: p.updated_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Returns all lti param records for the given user id
  """
  def all_user_lti_params(user_id) do
    from(p in LtiParams,
      where: p.user_id == ^user_id
    )
    |> Repo.all()
  end

  def peek_client_id(%{"aud" => [client_id | _]}), do: client_id
  def peek_client_id(%{"aud" => client_id}), do: client_id
  def peek_client_id(_), do: nil
end
