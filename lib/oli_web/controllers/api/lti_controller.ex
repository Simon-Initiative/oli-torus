defmodule OliWeb.Api.LtiController do
  use OliWeb, :controller

  alias Lti_1p3.Platform.LoginHint
  alias Lti_1p3.Platform.LoginHints
  alias Oli.Publishing.{DeliveryResolver, AuthoringResolver}
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  alias Oli.Lti.PlatformInstances
  alias Oli.Lti.Tokens

  require Logger

  action_fallback OliWeb.FallbackController

  @doc """
  Returns the launch details for an LTI activity, including the platform instance
  information and launch parameters.

  This endpoint is used by both the delivery and authoring contexts, depending on
  whether the request is made from a section or a project.
  """
  def launch_details(conn, %{"section_slug" => section_slug, "activity_id" => activity_id}) do
    with %Oli.Resources.Revision{activity_type_id: activity_type_id} <-
           DeliveryResolver.from_resource_id(section_slug, activity_id),
         %LtiExternalToolActivityDeployment{platform_instance: platform_instance, status: status} =
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: activity_type_id
           ) do
      user = conn.assigns[:current_user]

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(user.id, %{
          "section" => section_slug,
          "resource_id" => activity_id
        })

      json(conn, %{
        name: platform_instance.name,
        launch_params: %{
          iss: Oli.Utils.get_base_url(),
          login_hint: login_hint,
          client_id: platform_instance.client_id,
          target_link_uri: platform_instance.target_link_uri,
          login_url: platform_instance.login_url,
          status: status
        }
      })
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Activity not found"})
        |> halt()
    end
  end

  def launch_details(conn, %{"project_slug" => project_slug, "activity_id" => activity_id}) do
    with %Oli.Resources.Revision{activity_type_id: activity_type_id} <-
           AuthoringResolver.from_resource_id(project_slug, activity_id),
         %LtiExternalToolActivityDeployment{platform_instance: platform_instance, status: status} =
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: activity_type_id
           ) do
      author = conn.assigns[:current_author]

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(author.id, %{
          "project" => project_slug,
          "resource_id" => activity_id
        })

      json(conn, %{
        name: platform_instance.name,
        launch_params: %{
          iss: Oli.Utils.get_base_url(),
          login_hint: login_hint,
          client_id: platform_instance.client_id,
          target_link_uri: platform_instance.target_link_uri,
          login_url: platform_instance.login_url,
          status: status
        }
      })
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Activity not found"})
        |> halt()
    end
  end

  def deep_linking_launch_details(conn, %{
        "section_slug" => section_slug,
        "activity_id" => activity_id
      }) do
    with %Oli.Resources.Revision{activity_type_id: activity_type_id} <-
           DeliveryResolver.from_resource_id(section_slug, activity_id),
         %LtiExternalToolActivityDeployment{platform_instance: platform_instance, status: status} =
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: activity_type_id
           ) do
      user = conn.assigns[:current_user]

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(user.id, %{
          "section" => section_slug,
          "deep_linking" => "true"
        })

      json(conn, %{
        name: platform_instance.name,
        launch_params: %{
          iss: Oli.Utils.get_base_url(),
          login_hint: login_hint,
          client_id: platform_instance.client_id,
          target_link_uri: platform_instance.target_link_uri,
          login_url: platform_instance.login_url,
          status: status,
          lti_message_type: "LtiDeepLinkingRequest"
        }
      })
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Activity not found"})
        |> halt()
    end
  end

  @doc """
  Returns the developer key configuration for LTI 1.3, including public JWK and
  platform-specific settings.

  This endpoint is used by LMS platforms, specifically Canvas, to configure the LTI tool.
  """
  def developer_key_json(conn, params) do
    {:ok, active_jwk} = Lti_1p3.get_active_jwk()

    public_jwk =
      JOSE.JWK.from_pem(active_jwk.pem)
      |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()
      |> (fn {_kty, public_jwk} -> public_jwk end).()
      |> Map.put("typ", active_jwk.typ)
      |> Map.put("alg", active_jwk.alg)
      |> Map.put("kid", active_jwk.kid)

    host =
      Application.get_env(:oli, OliWeb.Endpoint)
      |> Keyword.get(:url)
      |> Keyword.get(:host)

    developer_key_config = %{
      "title" => Oli.VendorProperties.product_short_name(),
      "scopes" => [
        "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
        "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly",
        "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
        "https://purl.imsglobal.org/spec/lti-ags/scope/score",
        "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly"
      ],
      "extensions" => [
        %{
          "platform" => "canvas.instructure.com",
          "settings" => %{
            "platform" => "canvas.instructure.com",
            "placements" => [
              %{
                "placement" => "link_selection",
                "message_type" => "LtiResourceLinkRequest",
                "icon_url" => Oli.VendorProperties.normalized_workspace_logo(host)
              },
              %{
                "placement" => "assignment_selection",
                "message_type" => "LtiResourceLinkRequest"
              },
              %{
                "placement" => "course_navigation",
                "message_type" => "LtiResourceLinkRequest",
                "default" => get_course_navigation_default(params),
                "windowTarget" => "_blank"
              }
              ## TODO: add support for more placement types in the future, possibly configurable by LMS admin
              # assignment_selection when we support deep linking
              # %{
              #   "placement" => "assignment_selection",
              #   "message_type" => "LtiDeepLinkingRequest",
              #   "custom_fields" => %{
              #     "assignment_id" => "$Canvas.assignment.id"
              #   }
              # },
              # %{
              #   "placement" => "homework_submission",
              #   "message_type" => "LtiDeepLinkingRequest"
              # },
              # %{
              #   "placement" => "tool_configuration",
              #   "message_type" => "LtiResourceLinkRequest",
              #   "target_link_uri" => "https://#{host}/lti/configure"
              # },
              # ...
            ]
          },
          "privacy_level" => "public"
        }
      ],
      "public_jwk" => %{
        "e" => public_jwk["e"],
        "n" => public_jwk["n"],
        "alg" => public_jwk["alg"],
        "kid" => public_jwk["kid"],
        "kty" => "RSA",
        "use" => "sig"
      },
      "description" => "Create, deliver and iteratively improve course content",
      "custom_fields" => %{},
      "public_jwk_url" => "https://#{host}/.well-known/jwks.json",
      "target_link_uri" => "https://#{host}/lti/launch",
      "oidc_initiation_url" => "https://#{host}/lti/login"
    }

    conn
    |> json(developer_key_config)
  end

  defp get_course_navigation_default(%{"course_navigation_default" => "enabled"}), do: "enabled"
  defp get_course_navigation_default(_params), do: "disabled"

  @doc """
  Returns the JSON Web Key Set (JWKS) for LTI 1.3, which contains the public keys
  used for signing and verifying LTI requests.
  """
  def jwks(conn, _params) do
    conn
    |> json(Lti_1p3.get_all_public_keys())
  end

  @doc """
  Handles the OAuth 2.0 client credentials grant type for LTI 1.3.

  This endpoint is used to obtain an access token for LTI platform instances (tools)
  that is required for using the LTI 1.3 service endpoints.
  """
  def auth_token(conn, params) do
    with %{
           "grant_type" => "client_credentials",
           "client_assertion" => client_assertion,
           "scope" => scope
         } <- params,
         {:ok, %{sub: client_id}} <-
           validate_client_assertion(client_assertion),
         {:ok, scope} <-
           validate_scope(scope, [
             "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
             "https://purl.imsglobal.org/spec/lti-ags/scope/score"
           ]),
         {:ok, access_token, expires_in} <-
           Tokens.issue_access_token(client_id, scope) do
      conn
      |> put_resp_content_type("application/json")
      |> json(%{
        "access_token" => access_token,
        "token_type" => "bearer",
        "expires_in" => expires_in,
        "scope" => scope
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_request", error_description: to_string(reason)})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_request"})
    end
  end

  defp validate_client_assertion(client_assertion) do
    with {:ok, %JOSE.JWT{fields: %{"iss" => client_id, "sub" => client_id}}} <-
           peek_jwt(client_assertion),
         %JOSE.JWS{fields: %{"kid" => kid}} <- JOSE.JWT.peek_protected(client_assertion),
         {:ok, _iss, _sub} <- validate_matching_iss_sub(client_id, client_id),
         {:ok, platform_instance} <- get_platform_instance_by_client_id(client_id),
         {:ok, jwk} <- get_jwk_for_assertion(platform_instance.keyset_url, kid),
         {true, _jwt, _jws} <- JOSE.JWT.verify(jwk, client_assertion) do
      {:ok, %{sub: client_id}}
    else
      e ->
        Logger.error("Failed to validate client assertion: #{inspect(e)}")
        {:error, :invalid_client_assertion}
    end
  end

  defp validate_matching_iss_sub(iss, sub) do
    if iss == sub do
      {:ok, iss, sub}
    else
      {:error, :mismatched_iss_sub}
    end
  end

  defp get_platform_instance_by_client_id(client_id) do
    case PlatformInstances.get_platform_instance_by_client_id(client_id) do
      nil ->
        {:error, :platform_instance_not_found}

      platform_instance ->
        {:ok, platform_instance}
    end
  end

  defp validate_scope(scope, valid_scopes) do
    scopes =
      scope
      |> String.split(" ")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    if Enum.all?(scopes, &(&1 in valid_scopes)) do
      {:ok, scope}
    else
      {:error, :invalid_scope}
    end
  end

  defp peek_jwt(client_assertion) do
    try do
      jwt = JOSE.JWT.peek(client_assertion)

      {:ok, jwt}
    rescue
      _ ->
        {:error, :invalid_jwt}
    end
  end

  defp get_jwk_for_assertion(keyset_url, kid) do
    keys =
      fetch_public_keyset(keyset_url)
      |> Map.get("keys", [])

    cond do
      is_nil(kid) ->
        # If no kid is provided, assume the first key in the set is the active one
        Logger.warning(
          "No 'kid' provided in client_assertion, using first key in keyset from #{keyset_url}"
        )

        case keys do
          [] ->
            {:error, :no_keys_available}

          [first_key | _] ->
            {:ok, JOSE.JWK.from_map(first_key)}
        end

      true ->
        case Enum.find(keys, fn key -> key["kid"] == kid end) do
          nil -> {:error, :key_not_found}
          key -> {:ok, JOSE.JWK.from_map(key)}
        end
    end
  end

  def fetch_public_keyset(keyset_url) do
    case Oli.HTTP.http().get(keyset_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode!(body)

      error ->
        error
    end
  end

  @doc """
  Handles the Deep Linking response from the LTI tool.
  This endpoint receives the JWT containing the content items selected by the user.
  """
  def deep_linking(conn, params) do
    # Extract the JWT from the request
    jwt = params["JWT"]

    # For now, we'll just log the JWT and return success
    # In a full implementation, you would:
    # 1. Validate the JWT signature
    # 2. Parse the content items from the JWT
    # 3. Create resources in your system based on the selected content
    Logger.info("Received deep linking JWT: #{inspect(jwt)}")

    json(conn, %{
      status: "success",
      message: "Deep linking response received successfully"
    })
  end
end
