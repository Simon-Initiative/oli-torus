defmodule Oli.Lti.LtiParamsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Lti.LtiParams

  @context_claim "https://purl.imsglobal.org/spec/lti/claim/context"
  @deployment_claim "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

  describe "create_or_update_lti_params/2" do
    setup do
      [user: insert(:user)]
    end

    test "persists the params of a launch that names its identity", %{user: user} do
      assert {:ok, persisted} =
               LtiParams.create_or_update_lti_params(
                 Oli.Lti.TestHelpers.all_default_claims(),
                 user.id
               )

      assert persisted.user_id == user.id
      refute is_nil(persisted.context_id)
    end

    test "refuses a launch whose identity claims are malformed, without raising", %{user: user} do
      claims = Oli.Lti.TestHelpers.all_default_claims()

      malformed = [
        {"list context", Map.put(claims, @context_claim, [])},
        {"context without id", Map.put(claims, @context_claim, %{})},
        {"non binary context id", put_in(claims, [@context_claim, "id"], 7)},
        {"oversized context id",
         put_in(claims, [@context_claim, "id"], String.duplicate("c", 256))},
        {"missing deployment", Map.delete(claims, @deployment_claim)},
        {"non binary deployment", Map.put(claims, @deployment_claim, 7)},
        {"missing issuer", Map.delete(claims, "iss")},
        {"context id with a NUL byte",
         put_in(claims, [@context_claim, "id"], "x" <> <<0>> <> "y")},
        {"deployment with invalid utf8", Map.put(claims, @deployment_claim, <<0xFF, 0xFE>>)}
      ]

      for {label, params} <- malformed do
        assert LtiParams.create_or_update_lti_params(params, user.id) ==
                 {:error, :invalid_launch_identity},
               "expected a refusal for a #{label} claim"
      end
    end
  end
end
