defmodule Oli.Lti_1_3 do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Lti_1_3.Registration
  alias Oli.Lti_1_3.Deployment

  def get_registration_by_kid(kid) do
    Repo.one(from r in Registration, where: r.kid == ^kid)
  end

  def get_deployment(registration, deployment_id) do
    registration_id = registration.id
    Repo.one(from r in Deployment, where: r.registration_id == ^registration_id and r.deployment_id == ^deployment_id)
  end

end
