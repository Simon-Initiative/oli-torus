defmodule OliWeb.LtiController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Lti_1p3.ContextRoles
  alias Oli.Lti_1p3.PlatformRoles
  alias Oli.Lti_1p3

  ## LTI 1.3
  def login(conn, params) do
    case Lti_1p3.OidcLogin.oidc_login_redirect_url(conn, params) do
      {:ok, conn, redirect_url} ->
        conn
        |> redirect(external: redirect_url)
      {:error, reason} ->
        render(conn, "lti_error.html", reason: reason)
    end
  end

  def launch(conn, _params) do
    case Lti_1p3.LaunchValidation.validate(conn, &get_public_key/2) do
      {:ok, conn, lti_params} ->
        deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
        case Lti_1p3.get_ird_by_deployment_id(deployment_id) do
          nil ->
            handle_valid_lti_1p3_launch(conn, lti_params, deployment_id)
          {institution, registration, deployment} ->
            handle_valid_lti_1p3_launch(conn, lti_params, institution, registration, deployment)
        end
      {:error, reason} ->
        render(conn, "basic_launch_invalid.html", reason: reason)
    end
  end

  def test(conn, _params) do
    case Lti_1p3.LaunchValidation.validate(conn, &get_public_key/2) do
      {:ok, conn, lti_params} ->
        render(conn, "lti_test.html", lti_params: lti_params)
      {:error, reason} ->
        render(conn, "basic_launch_invalid.html", reason: reason)
    end
  end

  def jwks(conn, _params) do
    # TODO: only display relavant jwks, not all - check the standard
    all_jwks = Oli.Lti_1p3.get_all_jwks()
      |> Enum.map(fn %{pem: pem, typ: typ, alg: alg, kid: kid} ->
        pem
        |> JOSE.JWK.from_pem
        |> JOSE.JWK.to_public
        |> JOSE.JWK.to_map()
        |> (fn {_kty, public_jwk} -> public_jwk end).()
        |> Map.put("typ", typ)
        |> Map.put("alg", alg)
        |> Map.put("kid", kid)
      end)

    key_map = %{
      keys: all_jwks
    }

    conn
    |> json(key_map)
  end

  defp handle_valid_lti_1p3_launch(conn, _lti_params, deployment_id) do
    # TODO: render(conn, "configure_deployment.html")
    render(conn, "basic_launch_invalid.html", reason: "Deployment with deployment_id '#{deployment_id}' does not exist")
  end

  defp handle_valid_lti_1p3_launch(conn, lti_params, institution, _registration, _deployment) do
    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]

    # update user values defined by the oidc standard per LTI 1.3 standard user identity claims
    # http://www.imsglobal.org/spec/lti/v1p3/#user-identity-claims
    case Accounts.insert_or_update_user(%{
      sub: lti_params["sub"],
      name: lti_params["name"],
      given_name: lti_params["given_name"],
      family_name: lti_params["family_name"],
      middle_name: lti_params["middle_name"],
      nickname: lti_params["nickname"],
      preferred_username:  lti_params["preferred_username"],
      profile: lti_params["profile"],
      picture: lti_params["picture"],
      website: lti_params["website"],
      email: lti_params["email"],
      email_verified: lti_params["email_verified"],
      gender: lti_params["gender"],
      birthdate: lti_params["birthdate"],
      zoneinfo: lti_params["zoneinfo"],
      locale: lti_params["locale"],
      phone_number: lti_params["phone_number"],
      phone_number_verified: lti_params["phone_number_verified"],
      address: lti_params["address"],
      institution_id: institution.id,
    }) do
      {:ok, user} ->
        # update user platform roles
        Accounts.update_user_platform_roles(user, PlatformRoles.get_roles_by_uris(lti_roles))

        # context claim is considered optional according to IMS http://www.imsglobal.org/spec/lti/v1p3/#context-claim
        # safeguard against the case that context is missing
        case lti_params["https://purl.imsglobal.org/spec/lti/claim/context"] do
          nil ->
            throw "Error getting context information from launch params"
          context ->
            %{"id" => context_id} = context
            %{"title" => context_title} = context

            # Update section specifics - if one exists. Enroll the user and also update the section details
            with {:ok, section} <- get_existing_section(context_id)
            do
              # transform lti_roles to a list only containing valid context roles (exclude all system and institution roles)
              context_roles = ContextRoles.get_roles_by_uris(lti_roles)

              enroll_user(user.id, section.id, context_roles)
              update_section_details(context_title, section)
            end

            # if account is linked to an author, sign them in
            conn = if user.author_id != nil do
              conn
              |> put_session(:current_author_id, user.author_id)
            else
              conn
            end

            # sign current user in and redirect to home page
            conn
            |> put_session(:current_user_id, user.id)
            |> redirect(to: Routes.delivery_path(conn, :index))

        end
        _ ->
          throw "Error creating user"
    end
  end

  # If a course section exists for the context_id, ensure that
  # this user has an enrollment in this section
  defp enroll_user(user_id, section_id, context_roles) do
    Sections.enroll(user_id, section_id, context_roles)
  end

  defp update_section_details(context_title, section) do
    Sections.update_section(section, %{title: context_title})
  end

  defp get_existing_section(context_id) do
    case Sections.get_section_by(context_id: context_id) do
      nil -> nil
      section -> {:ok, section}
    end
  end

  defp get_public_key(%Lti_1p3.Registration{key_set_url: key_set_url}, kid) do
    public_key_set = case HTTPoison.get(key_set_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode!(body)
      _ ->
        {:error, "Failed to fetch public key from registered platform url"}
    end

    public_key = Enum.find(public_key_set["keys"], fn key -> key["kid"] == kid end)
    |> JOSE.JWK.from

    {:ok, public_key}
  end
end
