defmodule OliWeb.LtiController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Institutions
  alias Oli.Institutions.PendingRegistration
  alias Oli.Predefined
  alias Oli.Slack
  alias Oli.Lti.LaunchContext
  alias Oli.Lti.LaunchErrors
  alias Oli.Lti.LaunchState
  alias Oli.Lti.LaunchTelemetry
  alias Oli.Lti.LtiParams
  alias Oli.Lti.PlatformInstances
  alias Oli.Utils.Appsignal
  alias OliWeb.UserAuth
  alias OliWeb.Common.Utils
  alias OliWeb.DeliveryWeb
  alias Lti_1p3
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Lti.PlatformInstances
  alias Oli.Lti.Tokens
  alias Oli.Lti.PlatformExternalTools
  alias Lti_1p3.Roles.ContextRoles
  alias Lti_1p3.Roles.PlatformRoles
  alias Lti_1p3.Tool.Services.AGS
  alias Lti_1p3.Tool.Services.NRPS

  require Logger

  ## LTI 1.3
  def login(conn, params) do
    request_id = LaunchState.request_id(conn)

    case build_login_redirect(params, request_id) do
      {:ok, launch_state, registration, redirect_url} ->
        conn
        |> maybe_put_legacy_state(launch_state)
        |> emit_login_start(launch_state, params)
        |> maybe_render_launch_helper(launch_state, registration, redirect_url)

      {:error,
       %{
         reason: :invalid_registration,
         msg: _msg,
         issuer: issuer,
         client_id: client_id,
         lti_deployment_id: lti_deployment_id
       }} ->
        handle_invalid_registration(conn, issuer, client_id, lti_deployment_id)

      {:error, error} ->
        render_launch_error(conn, LaunchErrors.classify(error), request_id: request_id)
    end
  end

  def launch(conn, params) do
    session_state = Plug.Conn.get_session(conn, "state")

    with {:ok, launch_state} <- LaunchState.resolve(params, session_state),
         :ok <- emit_launch_start(launch_state, params),
         {:ok, lti_params} <- validate_launch(params, launch_state) do
      emit_launch_validated(launch_state, lti_params)

      case handle_valid_lti_1p3_launch(lti_params) do
        {:ok, user} ->
          case LaunchContext.from_claims(lti_params) do
            {:ok, launch_context} ->
              conn
              |> UserAuth.create_session(user)
              |> assign(:current_user, user)
              |> DeliveryWeb.redirect_user_from_launch(launch_context,
                allow_new_section_creation: true
              )

            {:error, reason} ->
              render_launch_failure(conn, reason, launch_state, params)
          end

        {:error, reason} ->
          render_launch_failure(conn, reason, launch_state, params)
      end
    else
      {:error, %{reason: :invalid_registration, msg: _msg, issuer: issuer, client_id: client_id}} ->
        handle_invalid_registration(conn, issuer, client_id)

      {:error,
       %{
         reason: :invalid_deployment,
         msg: _msg,
         registration_id: registration_id,
         deployment_id: deployment_id
       }} ->
        handle_invalid_deployment(conn, params, registration_id, deployment_id)

      {:error, reason} ->
        render_launch_failure(conn, reason, nil, params)
    end
  end

  defp handle_valid_lti_1p3_launch(lti_params) do
    issuer = lti_params["iss"]
    client_id = LtiParams.peek_client_id(lti_params)
    deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]

    Oli.Repo.transaction(fn ->
      with {:ok, institution, registration} <-
             get_institution_and_registration(issuer, client_id, deployment_id),
           {:ok, user} <- create_or_update_lti_user(lti_params, institution),
           :ok <- create_or_update_lti_params(user, lti_params),
           :ok <- update_user_platform_roles(user, lti_params),
           {:ok, section} <- get_and_update_lti_section_details(lti_params, registration),
           :ok <- enroll_user(user, section, lti_params) do
        user
      else
        {:error, error} ->
          Oli.Repo.rollback(error)
      end
    end)
  end

  defp get_institution_and_registration(issuer, client_id, deployment_id) do
    case Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id) do
      nil ->
        {:error, :invalid_registration}

      {institution, registration, _deployment} ->
        {:ok, institution, registration}
    end
  end

  defp lti_roles_claim(lti_params) do
    case lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"] do
      nil -> {:error, :roles_claim_missing}
      roles -> {:ok, roles}
    end
  end

  defp get_and_update_lti_section_details(lti_params, registration) do
    case Sections.get_section_from_lti_params(lti_params) do
      nil ->
        {:ok, nil}

      section ->
        Sections.update_section(section, %{
          grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
          line_items_service_url: AGS.get_line_items_url(lti_params, registration),
          nrps_enabled: NRPS.nrps_enabled?(lti_params),
          nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
        })
    end
  end

  defp create_or_update_lti_user(lti_params, institution) do
    Accounts.insert_or_update_lms_user(
      %{
        sub: lti_params["sub"],
        name: lti_params["name"],
        given_name: lti_params["given_name"],
        family_name: lti_params["family_name"],
        middle_name: lti_params["middle_name"],
        nickname: lti_params["nickname"],
        preferred_username: lti_params["preferred_username"],
        profile: lti_params["profile"],
        picture: lti_params["picture"],
        website: lti_params["website"],
        email: lti_params["email"],
        email_verified: true,
        gender: lti_params["gender"],
        birthdate: lti_params["birthdate"],
        zoneinfo: lti_params["zoneinfo"],
        locale: lti_params["locale"],
        phone_number: lti_params["phone_number"],
        phone_number_verified: lti_params["phone_number_verified"],
        address: lti_params["address"],
        lti_institution_id: institution.id
      },
      institution.id
    )
  end

  defp update_user_platform_roles(user, lti_params) do
    with {:ok, lti_roles} <- lti_roles_claim(lti_params),
         platform_roles <- PlatformRoles.get_roles_by_uris(lti_roles) do
      case Accounts.update_user_platform_roles(user, platform_roles) do
        {:ok, _user} -> :ok
        {:error, _changeset} -> {:error, :failed_to_update_platform_roles}
      end
    end
  end

  defp create_or_update_lti_params(user, lti_params) do
    case LtiParams.create_or_update_lti_params(lti_params, user.id) do
      {:ok, _lti_params} -> :ok
      {:error, _changeset} -> {:error, :failed_to_create_or_update_lti_params}
    end
  end

  defp enroll_user(user, section, lti_params) do
    case section do
      nil ->
        # No section to enroll in, return :ok
        :ok

      section ->
        context_roles =
          ContextRoles.get_roles_by_uris(
            lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
          )

        with :ok <- Sections.ensure_enrollment_allowed(user, section) do
          case Sections.enroll(user.id, section.id, context_roles) do
            {:ok, _enrollment} ->
              :ok

            {:error, _changeset} ->
              {:error, :failed_to_enroll_user_in_section}
          end
        end
    end
  end

  def test(conn, params) do
    session_state = Plug.Conn.get_session(conn, "state")

    with {:ok, launch_state} <- LaunchState.resolve(params, session_state),
         {:ok, lti_params} <- validate_launch(params, launch_state) do
      render(conn, "lti_test.html", lti_params: lti_params)
    else
      {:error, reason} ->
        render_launch_error(conn, LaunchErrors.classify(reason))
    end
  end

  def authorize_redirect(conn, params) do
    case Lti_1p3.Platform.LoginHints.get_login_hint_by_value(params["login_hint"]) do
      nil ->
        render(conn, "lti_error.html",
          reason: "The current user must be the same user initiating the LTI request"
        )

      %Lti_1p3.Platform.LoginHint{context: context, session_user_id: _session_user_id} ->
        client_id = params["client_id"]

        {:ok, platform_instance} =
          PlatformInstances.get_platform_instance_by_client_id(client_id)

        {user, target_link_uri, activity_resource_id, roles, additional_claims, message_type} =
          case context do
            %{"project" => project_slug, "resource_id" => activity_resource_id} ->
              build_authorization_for(
                :authoring,
                conn,
                platform_instance,
                project_slug,
                activity_resource_id
              )

            %{
              "section" => section_slug,
              "resource_id" => activity_resource_id,
              "configure_deep_linking" => "true"
            } ->
              build_authorization_for(
                :configure_deep_linking,
                conn,
                platform_instance,
                section_slug,
                activity_resource_id
              )

            %{"section" => section_slug, "resource_id" => activity_resource_id} ->
              build_authorization_for(
                :delivery,
                conn,
                platform_instance,
                section_slug,
                activity_resource_id
              )

            _ ->
              Logger.error("Unsupported context value in login hint: #{Kernel.inspect(context)}")

              throw("Unsupported context value in login hint")
          end

        issuer = Oli.Utils.get_base_url()

        deployment =
          Oli.Lti.PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
            platform_instance_id: platform_instance.id
          )

        # Use the message type determined by the context
        message_type_claim =
          case message_type do
            :deep_linking_request ->
              Lti_1p3.Claims.MessageType.message_type(:lti_deep_linking_request)

            _ ->
              Lti_1p3.Claims.MessageType.message_type(:lti_resource_link_request)
          end

        claims = [
          # Required claims
          message_type_claim,
          Lti_1p3.Claims.Version.version("1.3.0"),
          Lti_1p3.Claims.DeploymentId.deployment_id(deployment.deployment_id),
          Lti_1p3.Claims.TargetLinkUri.target_link_uri(target_link_uri),
          Lti_1p3.Claims.Roles.roles(roles),
          # Optional claims
          Lti_1p3.Claims.PlatformInstance.platform_instance(
            PlatformInstances.platform_instance_guid(platform_instance),
            contact_email: Oli.VendorProperties.support_email(),
            description: Oli.VendorProperties.product_description(),
            name: Oli.VendorProperties.product_full_name(),
            url: Oli.Utils.get_base_url(),
            product_family_code: "oli-torus",
            version: Application.fetch_env!(:oli, :build).version
          )
          | additional_claims
        ]

        # Add resource link claim only for resource link requests
        claims =
          case message_type do
            :deep_linking_request -> claims
            _ -> [Lti_1p3.Claims.ResourceLink.resource_link(activity_resource_id) | claims]
          end

        case Lti_1p3.Platform.AuthorizationRedirect.authorize_redirect(
               params,
               user,
               issuer,
               claims
             ) do
          {:ok, redirect_uri, state, id_token} ->
            conn
            |> put_view(OliWeb.LtiHTML)
            |> put_root_layout({OliWeb.LayoutView, :lti_redirect})
            |> render("post_redirect.html",
              redirect_uri: redirect_uri,
              state: state,
              id_token: id_token
            )

          {:error, %{reason: _reason, msg: msg}} ->
            render(conn, "lti_error.html", reason: msg)
        end
    end
  end

  defp build_authorization_for(
         :authoring,
         conn,
         platform_instance,
         project_slug,
         activity_resource_id
       ) do
    author = conn.assigns[:current_author]
    project = Oli.Authoring.Course.get_project_by_slug(project_slug)

    roles =
      [
        Lti_1p3.Roles.ContextRoles.get_role(:context_content_developer)
      ] ++
        if Oli.Accounts.is_admin?(author),
          do: [
            Lti_1p3.Roles.PlatformRoles.get_role(:system_administrator),
            Lti_1p3.Roles.PlatformRoles.get_role(:institution_administrator)
          ],
          else: []

    # Build additional claims
    additional_claims = [
      Lti_1p3.Claims.Context.context(project.slug,
        title: project.title,
        type: ["http://purl.imsglobal.org/vocab/lis/v2/course#CourseOffering"]
      )
    ]

    {%Accounts.User{
       id: author.id,
       sub: "author-#{author.id}",
       email: author.email,
       email_verified: true,
       name: author.name,
       given_name: author.given_name,
       family_name: author.family_name,
       picture: author.picture
     }, platform_instance.target_link_uri, activity_resource_id, roles, additional_claims,
     :resource_link_request}
  end

  defp build_authorization_for(
         :delivery,
         conn,
         platform_instance,
         section_slug,
         activity_resource_id
       ) do
    user = conn.assigns[:current_user]
    author = conn.assigns[:current_author]
    section = Sections.get_section_by_slug(section_slug)

    context_roles =
      Lti_1p3.Roles.Lti_1p3_User.get_context_roles(user, section.slug)

    platform_roles =
      Lti_1p3.Roles.Lti_1p3_User.get_platform_roles(user)

    roles =
      context_roles ++
        platform_roles ++
        if Oli.Accounts.is_admin?(author) do
          [
            Lti_1p3.Roles.PlatformRoles.get_role(:system_administrator),
            Lti_1p3.Roles.PlatformRoles.get_role(:institution_administrator)
          ]
        else
          []
        end

    # If there is a section resource deep link for the activity,
    # use that as the target link URI. Otherwise, use the platform instance's target link URI.
    {target_link_uri, additional_claims} =
      case Oli.Lti.PlatformExternalTools.get_section_resource_deep_link_by(
             section_id: section.id,
             resource_id: activity_resource_id
           ) do
        nil ->
          {platform_instance.target_link_uri, []}

        %Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink{url: nil, custom: custom} ->
          {platform_instance.target_link_uri, maybe_add_custom_claims(custom)}

        %Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink{url: url, custom: custom} ->
          {url, maybe_add_custom_claims(custom)}
      end

    # Build additional claims
    additional_claims = [
      Lti_1p3.Claims.Context.context(section.slug,
        title: section.title,
        type: ["http://purl.imsglobal.org/vocab/lis/v2/course#CourseSection"]
      )
      | additional_claims
    ]

    # If the user has an activity attempt for the given activity_resource_id,
    # add the AGS endpoint to the additional claims
    additional_claims =
      case Core.get_latest_user_resource_attempt_for_activity(
             section.slug,
             user.id,
             # activity_resource_id is expected to be an database id integer
             String.to_integer(activity_resource_id)
           ) do
        %ResourceAttempt{attempt_guid: page_attempt_guid} ->
          [
            Lti_1p3.Claims.AgsEndpoint.endpoint(
              [
                "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
                "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
                "https://purl.imsglobal.org/spec/lti-ags/scope/score"
              ],
              lineitem:
                Oli.Utils.get_base_url() <>
                  "/lti/lineitems/#{page_attempt_guid}/#{activity_resource_id}"
            )
            | additional_claims
          ]

        _ ->
          additional_claims
      end

    {user, target_link_uri, activity_resource_id, roles, additional_claims,
     :resource_link_request}
  end

  defp build_authorization_for(
         :configure_deep_linking,
         conn,
         platform_instance,
         section_slug,
         activity_resource_id
       ) do
    user = conn.assigns[:current_user]
    author = conn.assigns[:current_author]
    section = Sections.get_section_by_slug(section_slug)

    context_roles =
      Lti_1p3.Roles.Lti_1p3_User.get_context_roles(user, section.slug)

    platform_roles =
      Lti_1p3.Roles.Lti_1p3_User.get_platform_roles(user)

    roles =
      context_roles ++
        platform_roles ++
        if Oli.Accounts.is_admin?(author) do
          [
            Lti_1p3.Roles.PlatformRoles.get_role(:system_administrator),
            Lti_1p3.Roles.PlatformRoles.get_role(:institution_administrator)
          ]
        else
          []
        end

    # Build additional claims for deep linking
    additional_claims = [
      Lti_1p3.Claims.Context.context(section.slug,
        title: section.title,
        type: ["http://purl.imsglobal.org/vocab/lis/v2/course#CourseSection"]
      ),
      Lti_1p3.Claims.DeepLinkingSettings.deep_linking_settings(
        Oli.Utils.get_base_url() <> "/lti/deep_link/#{section_slug}/#{activity_resource_id}",
        ["ltiResourceLink"],
        ["iframe", "window"],
        accept_multiple: false,
        auto_create: true
      )
    ]

    {user, platform_instance.target_link_uri, nil, roles, additional_claims,
     :deep_linking_request}
  end

  defp maybe_add_custom_claims(nil) do
    []
  end

  defp maybe_add_custom_claims(custom),
    do: [
      Lti_1p3.Claims.Custom.custom(custom)
    ]

  defp build_login_redirect(params, request_id) do
    with {:ok, issuer} <- require_param(params, "iss", :missing_issuer),
         {:ok, client_id} <- require_param(params, "client_id", :missing_client_id),
         {:ok, login_hint} <- require_param(params, "login_hint", :missing_login_hint),
         {:ok, target_link_uri} <-
           require_param(params, "target_link_uri", :missing_target_link_uri),
         %Lti_1p3.Tool.Registration{} = registration <-
           Lti_1p3.Tool.get_registration_by_issuer_client_id(issuer, client_id),
         {:ok, launch_state} <- LaunchState.issue(params, request_id: request_id) do
      query_params =
        %{
          "scope" => "openid",
          "response_type" => "id_token",
          "response_mode" => "form_post",
          "prompt" => "none",
          "client_id" => client_id,
          "redirect_uri" => target_link_uri,
          "state" => launch_state["token"],
          "nonce" => launch_state["nonce"],
          "login_hint" => login_hint
        }
        |> maybe_put_param("lti_message_hint", params["lti_message_hint"])

      redirect_url = registration.auth_login_url <> "?" <> URI.encode_query(query_params)
      {:ok, launch_state, registration, redirect_url}
    else
      nil ->
        {:error,
         %{
           reason: :invalid_registration,
           msg: "Registration not found",
           issuer: params["iss"],
           client_id: params["client_id"],
           lti_deployment_id: params["lti_deployment_id"]
         }}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  defp maybe_put_legacy_state(conn, %{"flow_mode" => "legacy_session", "token" => token}) do
    put_session(conn, "state", token)
  end

  defp maybe_put_legacy_state(conn, _launch_state), do: conn

  defp maybe_render_launch_helper(
         conn,
         %{"flow_mode" => "client_storage"} = launch_state,
         registration,
         redirect_url
       ) do
    payload =
      Jason.encode!(%{
        state: launch_state["token"],
        nonce: launch_state["nonce"],
        request_id: launch_state["request_id"]
      })

    conn
    |> put_view(OliWeb.LtiHTML)
    |> put_format("html")
    |> render(:launch_helper,
      auth_origin: origin(registration.auth_login_url),
      redirect_url: redirect_url,
      request_id: launch_state["request_id"],
      state_key: LaunchState.state_storage_key(launch_state),
      state_payload: payload,
      storage_target: launch_state["storage_target"] || "_parent"
    )
  end

  defp maybe_render_launch_helper(conn, _launch_state, _registration, redirect_url) do
    redirect(conn, external: redirect_url)
  end

  defp validate_launch(params, %{"token" => state_token} = launch_state) do
    with {:ok, claims} <- Lti_1p3.Tool.LaunchValidation.validate(params, state_token),
         :ok <- validate_launch_state_claims(launch_state, claims) do
      {:ok, claims}
    end
  end

  defp render_launch_failure(conn, reason, launch_state, params) do
    classification = LaunchErrors.classify(reason, launch_failure_context(launch_state, params))

    metadata =
      telemetry_metadata(launch_state, params) |> Map.put(:classification, classification)

    Logger.warning("LTI launch failed", Map.to_list(metadata))
    LaunchTelemetry.emit_failure(metadata)

    case classification do
      :embedded_storage_blocked ->
        LaunchTelemetry.emit_recovery(metadata)
        render_launch_recovery(conn, classification, metadata)

      :missing_state ->
        if Map.get(metadata, :storage_supported) do
          LaunchTelemetry.emit_recovery(metadata)
          render_launch_recovery(conn, classification, metadata)
        else
          render_launch_error(conn, classification, request_id: metadata[:request_id])
        end

      :invalid_registration ->
        claims = peek_launch_claims(params)
        handle_invalid_registration(conn, claims["iss"], LtiParams.peek_client_id(claims))

      :invalid_deployment ->
        deployment_id =
          peek_launch_claims(params)["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]

        handle_invalid_deployment(conn, params, nil, deployment_id)

      :launch_handler_failure ->
        Appsignal.capture_error("Failed to handle valid LTI launch", metadata)
        render_launch_error(conn, classification, request_id: metadata[:request_id])

      _ ->
        render_launch_error(conn, classification, request_id: metadata[:request_id])
    end
  end

  defp render_launch_error(conn, classification, opts \\ []) do
    details = LaunchErrors.details(classification)

    conn
    |> put_status(Keyword.get(opts, :status, :bad_request))
    |> render("lti_error.html",
      guidance: details.guidance,
      message: details.message,
      request_id: Keyword.get(opts, :request_id),
      title: details.title
    )
  end

  defp render_launch_recovery(conn, classification, metadata) do
    details = LaunchErrors.details(classification)

    conn
    |> put_status(:bad_request)
    |> render("lti_recovery.html",
      guidance: details.guidance,
      message: details.message,
      request_id: metadata[:request_id],
      title: details.title
    )
  end

  defp emit_login_start(conn, launch_state, params) do
    LaunchTelemetry.emit_start(telemetry_metadata(launch_state, params))
    conn
  end

  defp emit_launch_start(launch_state, params) do
    LaunchTelemetry.emit_start(telemetry_metadata(launch_state, params))
    :ok
  end

  defp emit_launch_validated(launch_state, lti_params) do
    launch_context =
      Map.put(
        telemetry_metadata(launch_state, lti_params),
        :deployment_id,
        lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
      )

    LaunchTelemetry.emit_validated(launch_context)
  end

  defp telemetry_metadata(launch_state, params) do
    claims = peek_launch_claims(params)

    %{
      client_id: params["client_id"] || LtiParams.peek_client_id(claims),
      deployment_id: claims["https://purl.imsglobal.org/spec/lti/claim/deployment_id"],
      embedded_context: embedded_context?(params, claims),
      flow_mode: (launch_state && launch_state["flow_mode"]) || LaunchState.flow_mode(params),
      issuer: params["iss"] || claims["iss"],
      message_type: claims["https://purl.imsglobal.org/spec/lti/claim/message_type"],
      request_id: launch_state && launch_state["request_id"],
      storage_supported:
        if(launch_state,
          do: launch_state["storage_supported"],
          else: LaunchState.storage_supported?(params)
        )
    }
  end

  defp launch_failure_context(launch_state, params) do
    %{
      flow_mode: (launch_state && launch_state["flow_mode"]) || LaunchState.flow_mode(params),
      storage_supported:
        if(launch_state,
          do: launch_state["storage_supported"],
          else: LaunchState.storage_supported?(params)
        )
    }
  end

  defp embedded_context?(params, claims) do
    LaunchState.storage_supported?(params) ||
      get_in(claims, [
        "https://purl.imsglobal.org/spec/lti/claim/launch_presentation",
        "document_target"
      ]) ==
        "iframe"
  end

  defp peek_launch_claims(%{"id_token" => id_token}) when is_binary(id_token) do
    case Lti_1p3.Utils.peek_claims(id_token) do
      {:ok, claims} -> claims
      _ -> %{}
    end
  end

  defp peek_launch_claims(_params), do: %{}

  defp require_param(params, key, reason) do
    case params[key] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, reason}
    end
  end

  defp maybe_put_param(params, _key, nil), do: params
  defp maybe_put_param(params, key, value), do: Map.put(params, key, value)

  defp validate_launch_state_claims(launch_state, claims) do
    state_issuer = launch_state["iss"]
    state_client_id = launch_state["client_id"]
    claim_issuer = claims["iss"]
    claim_client_id = LtiParams.peek_client_id(claims)

    if state_issuer == claim_issuer and state_client_id == claim_client_id do
      :ok
    else
      {:error, :mismatched_state}
    end
  end

  defp origin(url) do
    uri = URI.parse(url)
    scheme = uri.scheme || "https"
    host = uri.host || ""
    port = if uri.port, do: ":#{uri.port}", else: ""
    "#{scheme}://#{host}#{port}"
  end

  @doc """
  Handles the Deep Linking response from the LTI tool.
  This endpoint receives the JWT containing the content items selected by the user.
  """
  def deep_link(
        conn,
        %{"JWT" => jwt, "section_slug" => section_slug, "resource_id" => resource_id} = _params
      ) do
    with {:ok, claims} <- validate_deep_linking_jwt(jwt),
         {:ok, content_item} <- require_single_content_item(claims),
         :ok <- require_lti_resource_link_type(content_item),
         {:ok, section} <- get_section_by_slug(section_slug),
         :ok = process_deep_linking_content_item(content_item, section.id, resource_id) do
      # Render success page with postMessage communication
      conn
      |> put_view(OliWeb.LtiHTML)
      |> put_layout(false)
      |> put_format("html")
      |> render(:deep_link_success, content_item: content_item)
    else
      {:error, _reason, error_description} ->
        conn
        |> put_view(OliWeb.LtiHTML)
        |> put_layout(false)
        |> put_format("html")
        |> put_status(:bad_request)
        |> render(:deep_link_error, error_description: error_description)

      {:error, reason} ->
        error_description = to_string(reason)

        conn
        |> put_view(OliWeb.LtiHTML)
        |> put_layout(false)
        |> put_format("html")
        |> put_status(:bad_request)
        |> render(:deep_link_error, error_description: error_description)
    end
  end

  defp get_section_by_slug(section_slug) do
    case Sections.get_section_by_slug(section_slug) do
      %Sections.Section{} = section ->
        {:ok, section}

      nil ->
        {:error, :section_not_found}
    end
  end

  defp validate_deep_linking_jwt(jwt) do
    with {:ok, %JOSE.JWT{fields: %{"iss" => client_id, "aud" => audience}}} <-
           Tokens.peek_jwt(jwt),
         %JOSE.JWS{fields: %{"kid" => kid}} <- JOSE.JWT.peek_protected(jwt),
         {:ok, platform_instance} <-
           PlatformInstances.get_platform_instance_by_client_id(client_id),
         {:ok, jwk} <- Tokens.get_jwk_for_assertion(platform_instance.keyset_url, kid),
         {true, jwt, _jws} <- JOSE.JWT.verify(jwk, jwt),
         jwt_claims <- jwt.fields,
         :ok <- validate_audience(audience),
         :ok <- validate_message_type(jwt_claims) do
      {:ok, jwt_claims}
    else
      e ->
        Logger.error("Failed to validate deep linking JWT: #{inspect(e)}")
        {:error, :invalid_deep_linking_jwt}
    end
  end

  defp validate_audience(audience) when is_list(audience),
    do: audience |> hd() |> validate_audience()

  defp validate_audience(audience) do
    expected_audience = Oli.Utils.get_base_url()

    if audience == expected_audience do
      :ok
    else
      {:error, :invalid_audience}
    end
  end

  defp validate_message_type(%{
         "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiDeepLinkingResponse"
       }) do
    :ok
  end

  defp validate_message_type(_) do
    {:error, :invalid_message_type}
  end

  defp require_single_content_item(%{
         "https://purl.imsglobal.org/spec/lti-dl/claim/content_items" => content_items
       }) do
    if is_list(content_items) and length(content_items) == 1 do
      {:ok, hd(content_items)}
    else
      {:error, :invalid_content_item,
       "Expected exactly one content item, got #{length(content_items)}"}
    end
  end

  defp require_lti_resource_link_type(%{"type" => "ltiResourceLink"}), do: :ok

  defp require_lti_resource_link_type(_),
    do: {:error, :invalid_content_item_type, "Expected content item type to be 'ltiResourceLink'"}

  defp process_deep_linking_content_item(content_item, section_id, resource_id) do
    Logger.info("Processing deep linking content item: #{inspect(content_item)}")

    case PlatformExternalTools.upsert_section_resource_deep_link(%{
           type: content_item["type"],
           title: content_item["title"],
           text: content_item["text"],
           url: content_item["url"],
           custom: content_item["custom"],
           resource_id: resource_id,
           section_id: section_id
         }) do
      {:ok, _deep_link} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to create section resource deep link: #{inspect(reason)}")
        {:error, :failed_to_create_deep_link}
    end

    :ok
  end

  @doc """
  Displays the registration form for institutions.

  This route is accessed via GET with CSRF protection enabled, allowing LiveView
  components (like TechSupportLive) to function properly. Registration params are
  retrieved from the session, which were stored during the redirect from login/launch.
  """
  def show_registration_form(conn, _params) do
    # Retrieve params from session that were stored during redirect from login/launch
    params = get_session(conn, :pending_registration_params) || %{}
    issuer = params[:issuer] || params["issuer"]
    client_id = params[:client_id] || params["client_id"]
    deployment_id = params[:deployment_id] || params["deployment_id"]

    show_registration_page(conn, issuer, client_id, deployment_id)
  end

  def request_registration(
        conn,
        %{"pending_registration" => pending_registration_attrs} = _params
      ) do
    case Institutions.create_pending_registration(pending_registration_attrs) do
      {:ok, pending_registration} ->
        # send a Slack notification regarding the new registration request
        Slack.send(%{
          "username" => "Torus Bot",
          "icon_emoji" => ":robot_face:",
          "blocks" => [
            %{
              "type" => "section",
              "text" => %{
                "type" => "mrkdwn",
                "text" =>
                  "New registration request from *#{pending_registration.name}*. <#{conn.scheme}://#{conn.host}/admin/institutions|Click here to view all pending requests>"
              }
            },
            %{
              "type" => "section",
              "fields" => [
                %{
                  "type" => "mrkdwn",
                  "text" => "*Name:*\n#{pending_registration.name}"
                },
                %{
                  "type" => "mrkdwn",
                  "text" => "*Institution Url:*\n#{pending_registration.institution_url}"
                },
                %{
                  "type" => "mrkdwn",
                  "text" => "*Contact Email:*\n#{pending_registration.institution_email}"
                },
                %{
                  "type" => "mrkdwn",
                  "text" => "*Location:*\n#{pending_registration.country_code}"
                },
                %{
                  "type" => "mrkdwn",
                  "text" =>
                    "*Date:*\n#{Utils.render_precise_date(pending_registration, :inserted_at, conn.assigns.ctx)}"
                }
              ]
            },
            %{
              "type" => "actions",
              "elements" => [
                %{
                  "type" => "button",
                  "text" => %{
                    "type" => "plain_text",
                    "text" => "Review Request"
                  },
                  "url" => "#{conn.scheme}://#{conn.host}/admin/institutions"
                }
              ]
            }
          ]
        })

        conn
        |> render("registration_pending.html", pending_registration: pending_registration)

      {:error, changeset} ->
        conn
        |> render("register.html",
          conn: conn,
          changeset: changeset,
          submit_action: Routes.lti_path(conn, :request_registration),
          country_codes: Predefined.country_codes(),
          world_universities_and_domains: Predefined.world_universities_and_domains(),
          lti_config_defaults: Predefined.lti_config_defaults(),
          issuer: pending_registration_attrs["issuer"],
          client_id: pending_registration_attrs["client_id"],
          deployment_id: pending_registration_attrs["deployment_id"]
        )
    end
  end

  # Redirect to registration form instead of rendering directly.
  # This allows the registration page to be served with CSRF protection,
  # which is required for LiveView components to establish WebSocket connections.
  defp handle_invalid_registration(conn, issuer, client_id, deployment_id \\ nil) do
    conn
    |> put_session(:pending_registration_params, %{
      issuer: issuer,
      client_id: client_id,
      deployment_id: deployment_id
    })
    |> redirect(to: "/lti/register_form")
  end

  # Similar to handle_invalid_registration - redirect to enable CSRF protection.
  defp handle_invalid_deployment(conn, _params, registration_id, deployment_id) do
    registration = Institutions.get_registration!(registration_id)

    conn
    |> put_session(:pending_registration_params, %{
      issuer: registration.issuer,
      client_id: registration.client_id,
      deployment_id: deployment_id
    })
    |> redirect(to: "/lti/register_form")
  end

  defp show_registration_page(conn, issuer, client_id, deployment_id) do
    # Only try to fetch pending registration if we have valid params.
    # Ecto queries don't allow comparison with nil, so we check first.
    pending_registration =
      if issuer != nil and client_id != nil do
        Oli.Institutions.get_pending_registration(issuer, client_id, deployment_id)
      else
        nil
      end

    case pending_registration do
      nil ->
        conn
        |> render("register.html",
          conn: conn,
          changeset: Institutions.change_pending_registration(%PendingRegistration{}),
          submit_action: Routes.lti_path(conn, :request_registration),
          country_codes: Predefined.country_codes(),
          world_universities_and_domains: Predefined.world_universities_and_domains(),
          lti_config_defaults: Predefined.lti_config_defaults(),
          issuer: issuer,
          client_id: client_id,
          deployment_id: deployment_id
        )

      pending_registration ->
        conn
        |> render("registration_pending.html", pending_registration: pending_registration)
    end
  end
end
