defmodule Oli.Lti_1p3 do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Lti_1p3.Registration
  alias Oli.Lti_1p3.Deployment

  def create_new_registration(attrs) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  def get_registration_by_kid(kid) do
    Repo.one(from r in Registration, where: r.kid == ^kid)
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

end
