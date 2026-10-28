defmodule Oli.Delivery.Sections.SectionSpecificationTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections.SectionSpecification
  alias Oli.Institutions.Institution
  alias Oli.Lti.LaunchIdentity
  alias Oli.Lti.Tool.{Deployment, Registration}

  @context_claim "https://purl.imsglobal.org/spec/lti/claim/context"

  describe "apply/2" do
    test "binds the section to the validated identity, not to the raw claims" do
      identity = %LaunchIdentity{
        issuer: "https://platform.example.edu",
        client_id: "client-1",
        deployment_id: "deployment-1",
        context_id: "identity-context"
      }

      spec = %SectionSpecification.Lti{
        # The claims disagree with the identity the boundary validated.
        lti_params: %{@context_claim => %{"id" => "claims-context"}},
        institution: %Institution{id: 11},
        registration: %Registration{line_items_service_domain: nil},
        deployment: %Deployment{id: 22},
        identity: identity
      }

      applied = SectionSpecification.apply(%{}, spec)

      assert applied.context_id == "identity-context"
      refute applied.context_id == "claims-context"
      assert applied.institution_id == 11
      assert applied.lti_1p3_deployment_id == 22
      refute applied.open_and_free
    end

    test "a direct specification is open and free" do
      assert SectionSpecification.apply(%{}, %SectionSpecification.Direct{}) == %{
               open_and_free: true
             }
    end
  end
end
