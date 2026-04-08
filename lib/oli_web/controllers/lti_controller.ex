defmodule OliWeb.LtiController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Institutions
  alias Oli.Institutions.PendingRegistration
  alias Oli.Lti.KeysetCache
  alias Oli.Lti.LaunchAttempts
  alias Oli.Lti.LaunchErrors
  alias Oli.Predefined
  alias Oli.Slack
  alias Oli.Lti.LtiParams
  alias Oli.Lti.PlatformInstances
  alias OliWeb.UserAuth
  alias OliWeb.Common.Utils
  alias OliWeb.LtiRedirect
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
    case build_login_launch(conn, params) do
      {:ok, attempt, redirect_url} ->
        conn
        |> maybe_put_legacy_state(attempt)
        |> maybe_render_launch_helper(attempt, redirect_url, request_id(conn), params)

      {:error,
       %{
         reason: :invalid_registration,
         msg: _msg,
         issuer: issuer,
         client_id: client_id,
         lti_deployment_id: lti_deployment_id
       }} ->
        handle_invalid_registration(conn, issuer, client_id, lti_deployment_id)

      {:error, %{msg: msg}} ->
        render_launch_error(conn, :validation_failure, request_id: request_id(conn), reason: msg)

      {:error, reason} ->
        render_launch_error(conn, :unknown_failure, request_id: request_id(conn), reason: reason)
    end
  end

  def launch(conn, params) do
    with {:ok, attempt} <- resolve_launch_attempt(conn, params),
         {:ok, attempt} <-
           LaunchAttempts.transition_attempt(
             attempt.id,
             attempt.lifecycle_state,
             :launching
           ),
         {:ok, lti_params} <- validate_launch(params, conn, attempt) do
      case handle_valid_lti_1p3_launch(lti_params) do
        {:ok, user} ->
          resolved_section = Sections.get_section_from_lti_params(lti_params)

          {:ok, attempt} =
            LaunchAttempts.transition_attempt(
              attempt.id,
              :launching,
              :launch_succeeded,
              launch_success_attrs(lti_params, resolved_section, user.id)
            )

          conn
          |> UserAuth.create_session(user)
          |> assign(:current_user, user)
          |> LtiRedirect.redirect_from_launch(attempt, allow_new_section_creation: true)

        {:error, :independent_learner_not_allowed} ->
          {:ok, _attempt} =
            LaunchAttempts.transition_attempt(
              attempt.id,
              :launching,
              :launch_failed,
              %{failure_classification: :post_auth_landing_failure}
            )

          render_launch_error(conn, :independent_learner_not_allowed,
            request_id: request_id(conn)
          )

        {:error, error} ->
          Logger.error("Failed to handle valid LTI 1.3 launch: #{inspect(error)}")

          {:ok, _attempt} =
            LaunchAttempts.transition_attempt(
              attempt.id,
              :launching,
              :launch_failed,
              %{failure_classification: :launch_handler_failure}
            )

          render_launch_error(conn, :launch_handler_failure, request_id: request_id(conn))
      end
    else
      {:error, {:invalid_registration, issuer, client_id, attempt}} ->
        {:ok, _attempt} =
          LaunchAttempts.transition_attempt(
            attempt.id,
            :launching,
            :registration_handoff,
            %{handoff_type: :registration_request, failure_classification: :invalid_registration}
          )

        handle_invalid_registration(conn, issuer, client_id)

      {:error, {:invalid_deployment, registration_id, deployment_id, attempt}} ->
        {:ok, _attempt} =
          LaunchAttempts.transition_attempt(
            attempt.id,
            :launching,
            :registration_handoff,
            %{handoff_type: :registration_request, failure_classification: :invalid_deployment}
          )

        handle_invalid_deployment(conn, params, registration_id, deployment_id)

      {:error, {classification, attempt}} when not is_nil(attempt) ->
        maybe_mark_attempt_failed(attempt, classification)
        render_launch_error(conn, classification, request_id: request_id(conn))

      {:error, classification} ->
        render_launch_error(conn, classification, request_id: request_id(conn))
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

    case Lti_1p3.Tool.LaunchValidation.validate(params, session_state) do
      {:ok, lti_params} ->
        render(conn, "lti_test.html", lti_params: lti_params)

      {:error, %{reason: _reason, msg: msg}} ->
        render(conn, "lti_error.html", reason: msg)
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

  defp build_login_launch(conn, params) do
    with {:ok, state_token, redirect_url} <-
           Lti_1p3.Tool.OidcLogin.oidc_login_redirect_url(params),
         {:ok, attempt} <-
           LaunchAttempts.create_launch_attempt(%{
             state_token: state_token,
             nonce: redirect_query_param(redirect_url, "nonce") || UUID.uuid4(),
             flow_mode: flow_mode(params),
             transport_method: transport_method(params),
             issuer: params["iss"],
             client_id: params["client_id"],
             deployment_id: params["lti_deployment_id"],
             target_link_uri: params["target_link_uri"],
             launch_presentation: %{"document_target" => "iframe"}
           }) do
      Logger.info(
        "Prepared LTI login launch attempt_id=#{attempt.id} transport_method=#{attempt.transport_method} request_id=#{request_id(conn)}"
      )

      {:ok, attempt, redirect_url}
    end
  end

  defp maybe_put_legacy_state(conn, %{
         transport_method: :session_storage,
         state_token: state_token
       }) do
    put_session(conn, "state", state_token)
  end

  defp maybe_put_legacy_state(conn, _attempt), do: conn

  defp maybe_render_launch_helper(
         conn,
         %{transport_method: :lti_storage_target} = attempt,
         redirect_url,
         request_id,
         params
       ) do
    state_payload =
      Jason.encode!(%{
        state: attempt.state_token,
        nonce: attempt.nonce,
        request_id: request_id
      })

    conn
    |> put_view(OliWeb.LtiHTML)
    |> put_format("html")
    |> render(:launch_helper,
      auth_origin: origin(redirect_url),
      redirect_url: redirect_url,
      request_id: request_id,
      state_key: "torus.lti.launch_attempt.#{attempt.id}",
      state_payload: state_payload,
      storage_target: params["lti_storage_target"] || "_parent"
    )
  end

  defp maybe_render_launch_helper(conn, _attempt, redirect_url, _request_id, _params) do
    redirect(conn, external: redirect_url)
  end

  defp resolve_launch_attempt(conn, params) do
    with {:ok, state_token} <- extract_state_token(params),
         {:ok, attempt} <- attempt_from_state_token(state_token) do
      case validate_legacy_session_state(conn, attempt) do
        :ok -> {:ok, attempt}
        {:error, classification} -> {:error, {classification, attempt}}
      end
    end
  end

  defp extract_state_token(%{"state" => state_token})
       when is_binary(state_token) and state_token != "",
       do: {:ok, state_token}

  defp extract_state_token(_params), do: {:error, :missing_state}

  defp attempt_from_state_token(state_token) do
    case LaunchAttempts.resolve_active_attempt(state_token) do
      {:ok, attempt} -> {:ok, attempt}
      {:error, :not_found} -> {:error, :missing_state}
      {:error, :expired} -> {:error, :expired_state}
      {:error, :consumed} -> {:error, :consumed_state}
    end
  end

  defp validate_legacy_session_state(conn, %{
         transport_method: :session_storage,
         state_token: state_token
       }) do
    case get_session(conn, "state") do
      nil -> {:error, :storage_blocked}
      ^state_token -> :ok
      _other -> {:error, :mismatched_state}
    end
  end

  defp validate_legacy_session_state(_conn, _attempt), do: :ok

  defp validate_launch(params, conn, attempt) do
    log_launch_validation_diagnostics(params)

    session_state =
      case attempt.transport_method do
        :session_storage -> get_session(conn, "state")
        :lti_storage_target -> attempt.state_token
      end

    case Lti_1p3.Tool.LaunchValidation.validate(params, session_state) do
      {:ok, lti_params} ->
        {:ok, lti_params}

      {:error, %{reason: :invalid_registration, issuer: issuer, client_id: client_id}} ->
        {:error, {:invalid_registration, issuer, client_id, attempt}}

      {:error,
       %{
         reason: :invalid_deployment,
         registration_id: registration_id,
         deployment_id: deployment_id
       }} ->
        {:error, {:invalid_deployment, registration_id, deployment_id, attempt}}

      {:error, reason} ->
        log_launch_validation_failure(reason, params, attempt)
        {:error, {:validation_failure, attempt}}
    end
  end

  defp maybe_mark_attempt_failed(%{lifecycle_state: :launching} = attempt, classification) do
    failure_classification =
      case classification do
        :expired_state -> :expired_state
        :consumed_state -> :consumed_state
        :missing_state -> :missing_state
        :mismatched_state -> :mismatched_state
        :storage_blocked -> :storage_blocked
        :post_auth_landing_failure -> :post_auth_landing_failure
        :launch_handler_failure -> :launch_handler_failure
        _ -> :validation_failure
      end

    _ =
      LaunchAttempts.transition_attempt(
        attempt.id,
        :launching,
        :launch_failed,
        %{failure_classification: failure_classification}
      )

    :ok
  end

  defp maybe_mark_attempt_failed(_attempt, _classification), do: :ok

  defp render_launch_error(conn, classification, opts) do
    details = LaunchErrors.details(classification)

    conn
    |> put_status(Keyword.get(opts, :status, :bad_request))
    |> render("lti_error.html",
      guidance: details.guidance,
      message: details.message || inspect(Keyword.get(opts, :reason)),
      reason: Keyword.get(opts, :reason),
      request_id: Keyword.get(opts, :request_id),
      title: details.title
    )
  end

  defp transport_method(%{"lti_storage_target" => target})
       when is_binary(target) and target != "",
       do: :lti_storage_target

  defp transport_method(_params), do: :session_storage

  defp flow_mode(params) do
    case transport_method(params) do
      :lti_storage_target -> :storage_assisted
      :session_storage -> :legacy_session
    end
  end

  defp redirect_query_param(redirect_url, key) do
    with %URI{query: query} <- URI.parse(redirect_url),
         true <- is_binary(query) do
      URI.decode_query(query)[key]
    else
      _ -> nil
    end
  end

  defp origin(url) do
    uri = URI.parse(url)
    scheme = uri.scheme || "https"
    host = uri.host || ""
    port = if uri.port, do: ":#{uri.port}", else: ""
    "#{scheme}://#{host}#{port}"
  end

  defp request_id(conn) do
    conn.assigns[:request_id] ||
      List.first(Plug.Conn.get_req_header(conn, "x-request-id")) ||
      UUID.uuid4()
  end

  defp log_launch_validation_diagnostics(params) do
    claims = peek_launch_claims(params)
    kid = peek_launch_kid(params)
    issuer = claims["iss"]
    client_id = LtiParams.peek_client_id(claims)

    metadata =
      case registration_keyset_metadata(issuer, client_id) do
        nil ->
          %{issuer: issuer, client_id: client_id, kid: kid}

        keyset_metadata ->
          Map.merge(%{issuer: issuer, client_id: client_id, kid: kid}, keyset_metadata)
      end

    Logger.info("LTI launch validation diagnostics #{format_log_metadata(metadata)}")
  end

  defp log_launch_validation_failure(reason, params, attempt) do
    claims = peek_launch_claims(params)
    kid = peek_launch_kid(params)

    metadata =
      %{
        reason: inspect(reason),
        kid: kid,
        issuer: claims["iss"],
        client_id: LtiParams.peek_client_id(claims),
        deployment_id: claims["https://purl.imsglobal.org/spec/lti/claim/deployment_id"],
        attempt_id: attempt.id,
        transport_method: attempt.transport_method
      }
      |> Map.merge(
        registration_keyset_metadata(claims["iss"], LtiParams.peek_client_id(claims)) || %{}
      )

    Logger.warning("LTI launch validation failed #{format_log_metadata(metadata)}")
  end

  defp registration_keyset_metadata(nil, _client_id), do: nil
  defp registration_keyset_metadata(_issuer, nil), do: nil

  defp registration_keyset_metadata(issuer, client_id) do
    case Institutions.get_registration_by_issuer_client_id(issuer, client_id) do
      nil ->
        nil

      registration ->
        case KeysetCache.get_keyset(registration.key_set_url) do
          {:ok, %{keys: keys, expires_at: expires_at}} ->
            %{
              key_set_url: registration.key_set_url,
              cached_kids: Enum.map(keys, &Map.get(&1, "kid")),
              keyset_expires_at: expires_at
            }

          {:error, :not_found} ->
            %{key_set_url: registration.key_set_url, cached_kids: [], keyset_cache: :miss}
        end
    end
  end

  defp peek_launch_claims(%{"id_token" => id_token}) when is_binary(id_token) do
    case Lti_1p3.Utils.peek_claims(id_token) do
      {:ok, claims} -> claims
      _ -> %{}
    end
  end

  defp peek_launch_claims(_params), do: %{}

  defp peek_launch_kid(%{"id_token" => id_token}) when is_binary(id_token) do
    case Joken.peek_header(id_token) do
      {:ok, %{"kid" => kid}} -> kid
      _ -> nil
    end
  end

  defp peek_launch_kid(_params), do: nil

  defp format_log_metadata(metadata) do
    metadata
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map_join(" ", fn {key, value} -> "#{key}=#{inspect(value)}" end)
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
  Displays the registration form for institutions using explicit request parameters.
  """
  def show_registration_form(conn, params) do
    issuer = params["issuer"]
    client_id = params["client_id"]
    deployment_id = params["deployment_id"]

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

  defp handle_invalid_registration(conn, issuer, client_id, deployment_id \\ nil) do
    redirect(conn,
      to:
        Routes.lti_path(conn, :show_registration_form, %{
          issuer: issuer,
          client_id: client_id,
          deployment_id: deployment_id
        })
    )
  end

  defp handle_invalid_deployment(conn, _params, registration_id, deployment_id) do
    registration = Institutions.get_registration!(registration_id)

    redirect(conn,
      to:
        Routes.lti_path(conn, :show_registration_form, %{
          issuer: registration.issuer,
          client_id: registration.client_id,
          deployment_id: deployment_id
        })
    )
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

  defp launch_success_attrs(lti_params, resolved_section, user_id) do
    context_id =
      case lti_params["https://purl.imsglobal.org/spec/lti/claim/context"] do
        %{"id" => context_id} -> context_id
        _ -> nil
      end

    resource_link_id =
      case lti_params["https://purl.imsglobal.org/spec/lti/claim/resource_link"] do
        %{"id" => resource_link_id} -> resource_link_id
        _ -> nil
      end

    %{
      context_id: context_id,
      resource_link_id: resource_link_id,
      message_type: lti_params["https://purl.imsglobal.org/spec/lti/claim/message_type"],
      resolved_section_id: resolved_section && resolved_section.id,
      roles: lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"] || [],
      user_id: user_id
    }
  end
end
