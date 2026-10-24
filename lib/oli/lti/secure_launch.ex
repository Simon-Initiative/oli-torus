defmodule Oli.Lti.SecureLaunch do
  @moduledoc """
  Moodle/SEB verified-entry adapter. Call only after normal LTI JWT, state,
  nonce and registration/deployment validation. The selected resource's policy,
  not a deployment selector or browser header, determines required evidence.
  This is launch-time evidence, not continuous browser attestation.
  """
  alias Oli.Delivery.SecureAssessments.Admission
  alias Oli.Institutions
  alias Oli.Lti.LtiParams

  @custom "https://purl.imsglobal.org/spec/lti/claim/custom"
  @deployment "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @context "https://purl.imsglobal.org/spec/lti/claim/context"
  @max_age 300
  @future_skew 30

  @doc "Verifies Moodle's signed assertion with the existing five-minute freshness window."
  @spec validate(map(), keyword()) :: {:ok, :verified} | {:error, atom()}
  def validate(claims, opts \\ []) do
    validate_assertion(
      Map.get(claims, @custom),
      Keyword.get(opts, :now, System.system_time(:second))
    )
  end

  @doc "Binds current authenticated evidence to the resolved learner/section/page; ordinary entry returns nil."
  @spec admission(%Oli.Accounts.User{}, map(), map()) ::
          {:ok, Admission.t() | nil} | {:error, atom()}
  def admission(user, %{section: section, resource: %{secure_delivery: true} = resource}, claims) do
    with true <- resource.graded == true,
         true <- bound?(user, section, resource, claims),
         {:ok, :verified} <- validate(claims) do
      {:ok,
       %Admission{
         user_id: user.id,
         section_id: section.id,
         resource_id: resource.resource_id,
         provider: :moodle_seb
       }}
    else
      false -> {:error, :secure_target_invalid}
      {:error, _} -> {:error, :secure_launch_required}
    end
  end

  def admission(_user, %{resource: nil}, claims) do
    case Map.get(claims, @custom) do
      %{"secure_delivery" => _} -> {:error, :secure_target_invalid}
      _ -> {:ok, nil}
    end
  end

  def admission(_user, _target, _claims), do: {:ok, nil}

  defp bound?(user, section, resource, claims) do
    with true <- user.sub == claims["sub"],
         %{"id" => context_id} <- claims[@context],
         true <- section.context_id == context_id and section.id == resource.section_id,
         {institution, _registration, deployment} <-
           Institutions.get_institution_registration_deployment(
             claims["iss"],
             LtiParams.peek_client_id(claims),
             claims[@deployment]
           ),
         true <- user.lti_institution_id == institution.id,
         true <- section.lti_1p3_deployment_id == deployment.id do
      true
    else
      _ -> false
    end
  end

  defp validate_assertion(%{"secure_delivery" => "seb"} = custom, now) do
    with true <- nonempty_string?(custom["secure_activity_id"]),
         true <- nonempty_string?(custom["seb_configuration_id"]),
         {:ok, timestamp} <- timestamp(custom["secure_verified_at"]) do
      cond do
        timestamp < now - @max_age -> {:error, :stale_assertion}
        timestamp > now + @future_skew -> {:error, :future_assertion}
        true -> {:ok, :verified}
      end
    else
      _ -> {:error, :malformed_assertion}
    end
  end

  defp validate_assertion(_, _), do: {:error, :missing_assertion}

  defp timestamp(value) when is_binary(value) and byte_size(value) in 1..12 do
    case Regex.match?(~r/\A[0-9]+\z/, value) do
      true -> {:ok, String.to_integer(value)}
      false -> :error
    end
  end

  defp timestamp(_), do: :error
  defp nonempty_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp nonempty_string?(_), do: false
end
