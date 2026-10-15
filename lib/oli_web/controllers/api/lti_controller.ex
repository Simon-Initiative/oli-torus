defmodule OliWeb.Api.LtiController do
  use OliWeb, :controller

  alias Lti_1p3.Platform.LoginHint
  alias Lti_1p3.Platform.LoginHints
  alias Oli.Delivery.Sections
  alias Oli.Lti.AuthoringLaunch
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  alias Oli.Lti.PlatformInstances
  alias Oli.Lti.SectionDeepLinkLaunch
  alias Oli.Lti.Tokens

  require Logger

  action_fallback OliWeb.FallbackController

  @lti_message_hint_salt "lti_message_hint"

  @doc """
  Returns the launch details for an LTI activity, including the platform instance
  information and launch parameters.

  This endpoint is used by both the delivery and authoring contexts, depending on
  whether the request is made from a section or a project.
  """
  def launch_details(conn, %{"section_slug" => section_slug, "activity_id" => activity_id}) do
    with %Oli.Resources.Revision{activity_type_id: activity_type_id} <-
           DeliveryResolver.from_resource_id(section_slug, activity_id),
         {:ok, section} <- get_section_by_slug(section_slug),
         %LtiExternalToolActivityDeployment{
           platform_instance: platform_instance,
           status: status,
           deep_linking_enabled: deep_linking_enabled
         } =
           deployment =
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: activity_type_id
           ) do
      user = conn.assigns[:current_user]
      current_author = conn.assigns[:current_author]

      can_configure_tool =
        SectionDeepLinkLaunch.can_configure?(
          SectionDeepLinkLaunch.actor(user, current_author),
          section,
          deployment
        )

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(user.id, %{
          "section" => section_slug,
          "resource_id" => activity_id
        })

      launch_params =
        build_launch_params(
          platform_instance,
          login_hint,
          deployment,
          endpoint: :section_launch_details,
          resource_id: activity_id
        )

      deep_link =
        PlatformExternalTools.get_section_resource_deep_link_by(
          section_id: section.id,
          resource_id: activity_id
        )

      json(conn, %{
        name: platform_instance.name,
        launch_params: launch_params,
        status: status,
        deep_linking_enabled: deep_linking_enabled,
        deep_link: deep_link,
        can_configure_tool: can_configure_tool
      })
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Activity not found"})
        |> halt()
    end
  end

  def launch_details(
        conn,
        %{"project_slug" => project_slug, "activity_id" => activity_id} = params
      ) do
    author = conn.assigns[:current_author]
    role = Map.get(params, "role", "developer")
    launch_type = Map.get(params, "launch_type", "regular")

    with true <- role in ["developer", "instructor"] and launch_type == "regular",
         {:ok, revision, deployment} <-
           AuthoringLaunch.resolve(author, project_slug, activity_id) do
      request_id = Ecto.UUID.generate()

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(author.id, %{
          "project_id" => Oli.Authoring.Course.get_project_by_slug(project_slug).id,
          "resource_id" => activity_id,
          "role" => role,
          "launch_type" => launch_type,
          "request_id" => request_id
        })

      platform = deployment.platform_instance
      selected_url = get_in(revision.content, ["deepLink", "url"])

      target =
        case selected_url do
          url when is_binary(url) -> url
          _ -> platform.target_link_uri
        end

      launch_params =
        build_launch_params(platform, login_hint, deployment,
          endpoint: :project_launch_details,
          resource_id: activity_id
        )
        |> Map.put(:target_link_uri, target)

      json(conn, %{
        name: platform.name,
        launch_params: launch_params,
        status: deployment.status,
        deep_linking_enabled: deployment.deep_linking_enabled,
        can_configure_tool: deployment.deep_linking_enabled,
        request_id: request_id
      })
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Launch unavailable for this author, activity, or launch choice"})
    end
  end

  @doc "Persists only the signed tool selection and returns the authoritative activity model."
  def authoring_deep_link_save(conn, %{
        "project_slug" => project,
        "activity_id" => activity,
        "token" => token
      }) do
    with true <- same_origin?(conn),
         {:ok, revision} <-
           AuthoringLaunch.save_result(conn.assigns[:current_author], project, activity, token) do
      json(conn, %{
        model: revision.content,
        title: revision.title,
        objectives: revision.objectives,
        tags: revision.tags
      })
    else
      {:error, :save_failed} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "The selection could not be saved. Try again."})

      _ ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "Selection expired or the editor changed. Close and launch the tool again."
        })
    end
  end

  def authoring_deep_link_save(conn, _),
    do: conn |> put_status(:bad_request) |> json(%{error: "A signed selection is required"})

  @doc "Returns authorized configuration launch details; projects require an active editor lock."
  def deep_linking_launch_details(
        conn,
        %{"project_slug" => project, "activity_id" => activity, "lock_id" => lock_id} = params
      ) do
    author = conn.assigns[:current_author]
    role = Map.get(params, "role", "developer")

    with true <- same_origin?(conn) and role in ["developer", "instructor"],
         {:ok, details} <- AuthoringLaunch.start_request(author, project, activity, lock_id),
         {:ok, %LoginHint{value: login_hint}} <-
           LoginHints.create_login_hint(author.id, %{
             "project_id" => Oli.Authoring.Course.get_project_by_slug(project).id,
             "resource_id" => to_string(activity),
             "role" => role,
             "launch_type" => "deep_link",
             "request_id" => details.request_id
           }) do
      deployment = details.deployment
      platform = deployment.platform_instance

      launch_params =
        build_launch_params(platform, login_hint, deployment,
          endpoint: :project_deep_linking_launch_details,
          resource_id: activity,
          lti_message_type: "LtiDeepLinkingRequest",
          authoring_request: details.request_token
        )

      json(conn, %{
        name: platform.name,
        launch_params: launch_params,
        status: deployment.status,
        deep_linking_enabled: true,
        can_configure_tool: true,
        request_id: details.request_id,
        request_token: details.request_token
      })
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Tool configuration requires an active editing lock"})
    end
  end

  def deep_linking_launch_details(conn, %{"project_slug" => _}),
    do: conn |> put_status(:bad_request) |> json(%{error: "The editing lock is required"})

  def deep_linking_launch_details(conn, %{
        "section_slug" => section_slug,
        "activity_id" => activity_id
      }) do
    actor =
      SectionDeepLinkLaunch.actor(conn.assigns[:current_user], conn.assigns[:current_author])

    with true <- same_origin?(conn),
         {:ok,
          %{
            section: section,
            deployment: deployment,
            request_id: request_id,
            request_token: request_token
          }} <-
           SectionDeepLinkLaunch.start_request(actor, section_slug, activity_id) do
      platform_instance = deployment.platform_instance

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(actor.id, %{
          "section_id" => section.id,
          "resource_id" => activity_id,
          "configure_deep_linking" => "true",
          "actor_type" => SectionDeepLinkLaunch.actor_type(actor),
          "request_id" => request_id
        })

      launch_params =
        build_launch_params(
          platform_instance,
          login_hint,
          deployment,
          endpoint: :deep_linking_launch_details,
          resource_id: activity_id,
          lti_message_type: "LtiDeepLinkingRequest"
        )

      json(conn, %{
        name: platform_instance.name,
        launch_params: launch_params,
        status: deployment.status,
        request_id: request_id,
        request_token: request_token
      })
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Tool configuration is unavailable"})
        |> halt()
    end
  end

  @doc "Cancels a section configuration request without undoing a committed selection."
  def cancel_deep_linking(conn, %{
        "section_slug" => slug,
        "activity_id" => id,
        "request_token" => token
      }) do
    actor =
      SectionDeepLinkLaunch.actor(conn.assigns[:current_user], conn.assigns[:current_author])

    result =
      case same_origin?(conn) do
        true -> SectionDeepLinkLaunch.cancel_request(actor, slug, id, token)
        false -> {:error, :configuration_unavailable}
      end

    case result do
      {:ok, status} ->
        json(conn, %{status: status})

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Tool configuration could not be cancelled"})
    end
  end

  def cancel_deep_linking(conn, _params),
    do:
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Tool configuration could not be cancelled"})

  defp same_origin?(conn) do
    uri = URI.parse(Oli.Utils.get_base_url())
    origin = URI.to_string(%{uri | path: nil, query: nil, fragment: nil})
    get_req_header(conn, "origin") == [origin]
  end

  defp get_section_by_slug(section_slug) do
    case Sections.get_section_by_slug(section_slug) do
      %Sections.Section{} = section ->
        {:ok, section}

      nil ->
        {:error, :section_not_found}
    end
  end

  defp build_launch_params(platform_instance, login_hint, deployment, opts) do
    deployment_id = deployment && deployment.deployment_id
    lti_message_type = Keyword.get(opts, :lti_message_type)
    endpoint = Keyword.fetch!(opts, :endpoint)

    launch_params =
      %{
        iss: Oli.Utils.get_base_url(),
        login_hint: login_hint,
        client_id: platform_instance.client_id,
        target_link_uri: platform_instance.target_link_uri,
        login_url: platform_instance.login_url,
        lti_deployment_id: deployment_id,
        lti_message_hint:
          sign_lti_message_hint(
            login_hint,
            deployment_id,
            endpoint,
            resource_id: Keyword.get(opts, :resource_id),
            lti_message_type: lti_message_type,
            authoring_request: Keyword.get(opts, :authoring_request)
          ),
        lti_message_type: lti_message_type
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    log_launch_param_generation(endpoint, launch_params)

    launch_params
  end

  defp sign_lti_message_hint(login_hint, deployment_id, endpoint, opts) do
    payload =
      %{
        "login_hint" => login_hint,
        "deployment_id" => deployment_id,
        "endpoint" => to_string(endpoint),
        "resource_id" => Keyword.get(opts, :resource_id),
        "lti_message_type" => Keyword.get(opts, :lti_message_type),
        "authoring_request" => Keyword.get(opts, :authoring_request)
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    Phoenix.Token.sign(OliWeb.Endpoint, @lti_message_hint_salt, payload)
  end

  defp log_launch_param_generation(endpoint, launch_params) do
    Logger.debug(fn ->
      "Generated external tool launch params endpoint=#{endpoint} " <>
        "issued_lti_deployment_id=#{Map.has_key?(launch_params, :lti_deployment_id)} " <>
        "issued_lti_message_hint=#{Map.has_key?(launch_params, :lti_message_hint)}"
    end)
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
    |> Oli.Plugs.NoCache.public_content()
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
    |> Oli.Plugs.NoCache.public_content()
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
             "https://purl.imsglobal.org/spec/lti-ags/scope/score",
             "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"
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
        Logger.error("Failed to issue access token: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_request", error_description: to_string(reason)})

      e ->
        Logger.error("Failed to issue access token: #{inspect(e)}")

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
         {:ok, platform_instance} <-
           PlatformInstances.get_platform_instance_by_client_id(client_id),
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

  defp peek_jwt(token) do
    try do
      jwt = JOSE.JWT.peek(token)

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
end
