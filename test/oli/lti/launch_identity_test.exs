defmodule Oli.Lti.LaunchIdentityTest do
  use ExUnit.Case, async: true

  alias Oli.Lti.LaunchIdentity

  @context_claim "https://purl.imsglobal.org/spec/lti/claim/context"
  @deployment_claim "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

  defp claims(overrides \\ %{}) do
    Map.merge(
      %{
        "iss" => "https://platform.example.edu",
        "aud" => "client-1",
        @deployment_claim => "deployment-1",
        @context_claim => %{"id" => "context-1"}
      },
      overrides
    )
  end

  test "builds an identity from complete claims" do
    assert {:ok, identity} = LaunchIdentity.from_claims(claims())

    assert identity == %LaunchIdentity{
             issuer: "https://platform.example.edu",
             client_id: "client-1",
             deployment_id: "deployment-1",
             context_id: "context-1"
           }
  end

  test "takes the first audience when the claim is a list" do
    assert {:ok, %LaunchIdentity{client_id: "client-1"}} =
             LaunchIdentity.from_claims(claims(%{"aud" => ["client-1", "client-2"]}))
  end

  test "refuses a launch that does not name every part of its identity" do
    for {label, overrides} <- [
          {"missing issuer", :drop_iss},
          {"nil issuer", %{"iss" => nil}},
          {"empty issuer", %{"iss" => ""}},
          {"integer issuer", %{"iss" => 7}},
          {"missing audience", :drop_aud},
          {"empty audience list", %{"aud" => []}},
          {"non binary audience head", %{"aud" => [7]}},
          {"empty client id", %{"aud" => ""}},
          {"missing deployment", :drop_deployment},
          {"nil deployment", %{@deployment_claim => nil}},
          {"empty deployment", %{@deployment_claim => ""}},
          {"integer deployment", %{@deployment_claim => 123}},
          {"missing context", :drop_context},
          {"list context", %{@context_claim => []}},
          {"context without id", %{@context_claim => %{}}},
          {"nil context id", %{@context_claim => %{"id" => nil}}},
          {"empty context id", %{@context_claim => %{"id" => ""}}},
          {"integer context id", %{@context_claim => %{"id" => 7}}}
        ] do
      params =
        case overrides do
          :drop_iss -> Map.delete(claims(), "iss")
          :drop_aud -> Map.delete(claims(), "aud")
          :drop_deployment -> Map.delete(claims(), @deployment_claim)
          :drop_context -> Map.delete(claims(), @context_claim)
          overrides -> claims(overrides)
        end

      assert LaunchIdentity.from_claims(params) == :error, "expected :error for #{label}"
    end
  end

  test "accepts 255 bytes in every field, the most the columns can hold by this bound" do
    longest = String.duplicate("c", 255)

    assert {:ok,
            %LaunchIdentity{
              issuer: ^longest,
              client_id: ^longest,
              deployment_id: ^longest,
              context_id: ^longest
            }} =
             LaunchIdentity.from_claims(
               claims(%{
                 "iss" => longest,
                 "aud" => longest,
                 @deployment_claim => longest,
                 @context_claim => %{"id" => longest}
               })
             )

    # Non-ASCII is accepted while it fits the byte bound, here exactly at it. The bound is a
    # storage limit; only deployment and context ids have a protocol limit to compare with.
    accented = String.duplicate("á", 127) <> "c"
    assert byte_size(accented) == 255

    assert {:ok, %LaunchIdentity{context_id: ^accented}} =
             LaunchIdentity.from_claims(claims(%{@context_claim => %{"id" => accented}}))
  end

  test "refuses 256 bytes in any field, so nothing longer than the bound reaches a column" do
    too_long = String.duplicate("c", 256)

    assert LaunchIdentity.from_claims(claims(%{@context_claim => %{"id" => too_long}})) == :error
    assert LaunchIdentity.from_claims(claims(%{@deployment_claim => too_long})) == :error
    assert LaunchIdentity.from_claims(claims(%{"iss" => too_long})) == :error
    assert LaunchIdentity.from_claims(claims(%{"aud" => too_long})) == :error

    # 128 accented characters are 256 bytes. `varchar(255)` counts characters, so the column
    # would hold them; this boundary is deliberately stricter and refuses them.
    assert LaunchIdentity.from_claims(
             claims(%{@context_claim => %{"id" => String.duplicate("á", 128)}})
           ) == :error
  end

  test "refuses values a character column cannot store, in every field" do
    with_nul = "x" <> <<0>> <> "y"
    invalid_utf8 = <<0xFF, 0xFE>>

    for bad <- [with_nul, invalid_utf8] do
      assert LaunchIdentity.from_claims(claims(%{@context_claim => %{"id" => bad}})) == :error
      assert LaunchIdentity.from_claims(claims(%{@deployment_claim => bad})) == :error
      assert LaunchIdentity.from_claims(claims(%{"iss" => bad})) == :error
      assert LaunchIdentity.from_claims(claims(%{"aud" => bad})) == :error
    end

    # The same claims without the NUL are accepted, so the refusal is the byte and not the shape.
    assert {:ok, %LaunchIdentity{context_id: "xy"}} =
             LaunchIdentity.from_claims(claims(%{@context_claim => %{"id" => "xy"}}))
  end

  test "refuses anything that is not a claims map" do
    for value <- [nil, [], "claims", 7, %{}] do
      assert LaunchIdentity.from_claims(value) == :error
    end
  end
end
