defmodule Oli.Lti_1p3Test do
  use Oli.DataCase

  alias Oli.Lti_1p3

  describe "lti 1.3 library" do
    setup do
      institution = institution_fixture()
      jwk = jwk_fixture()

      %{institution: institution, jwk: jwk}
    end

    test "create and get valid registration", %{institution: institution, jwk: jwk} do
      {:ok, registration} = Lti_1p3.create_new_registration(%{
        issuer: "some issuer",
        client_id: "some client_id",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        kid: "some kid",
        tool_jwk_id: jwk.id,
        institution_id: institution.id,
      })

      assert Lti_1p3.get_registration_by_kid("some kid") == registration
    end

    test "create and get valid deployment", %{institution: institution, jwk: jwk} do
      {:ok, registration} = Lti_1p3.create_new_registration(%{
        issuer: "some issuer",
        client_id: "some client_id",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        kid: "some kid",
        tool_jwk_id: jwk.id,
        institution_id: institution.id,
      })

      {:ok, deployment} = Lti_1p3.create_new_deployment(%{
        deployment_id: "some deployment_id",
        registration_id: registration.id
      })

      assert Lti_1p3.get_deployment(registration, deployment.deployment_id) == deployment
    end
  end
end
