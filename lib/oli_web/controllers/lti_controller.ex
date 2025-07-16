defmodule OliWeb.LtiController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Institutions
  alias Oli.Institutions.PendingRegistration
  alias Lti_1p3
  alias Oli.Predefined
  alias Oli.Slack
  alias OliWeb.Common.Utils
  alias OliWeb.UserAuth
  alias Oli.Lti.LtiParams
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
    case Lti_1p3.Tool.OidcLogin.oidc_login_redirect_url(params) do
      {:ok, state, redirect_url} ->
        conn
        |> put_session("state", state)
        |> redirect(external: redirect_url)

      {:error,
       %{
         reason: :invalid_registration,
         msg: _msg,
         issuer: issuer,
         client_id: client_id,
         lti_deployment_id: lti_deployment_id
       }} ->
        handle_invalid_registration(conn, issuer, client_id, lti_deployment_id)

      {:error, reason} ->
        render(conn, "lti_error.html", reason: reason)
    end
  end

  def launch(conn, params) do
    session_state = Plug.Conn.get_session(conn, "state")

    case Lti_1p3.Tool.LaunchValidation.validate(params, session_state) do
      {:ok, lti_params} ->
        case handle_valid_lti_1p3_launch(conn, lti_params) do
          {:ok, conn} ->
            conn

          {:error, e} ->
            Logger.error("Failed to handle valid LTI 1.3 launch: #{Kernel.inspect(e)}")

            render(conn, "lti_error.html", reason: "Failed to handle valid LTI 1.3 launch")
        end

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

      {:error, %{reason: _reason, msg: msg}} ->
        render(conn, "lti_error.html", reason: msg)
    end
  end

  defp handle_valid_lti_1p3_launch(conn, lti_params) do
    issuer = lti_params["iss"]
    client_id = LtiParams.peek_client_id(lti_params)
    deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]

    Oli.Repo.transaction(fn ->
      case Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id) do
        {institution, registration, _deployment} ->
          lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]

          # update user values defined by the oidc standard per LTI 1.3 standard user identity claims
          # http://www.imsglobal.org/spec/lti/v1p3/#user-identity-claims
          case Accounts.insert_or_update_lms_user(
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
               ) do
            {:ok, user} ->
              # update lti params and session to be associated with the current lms user
              {:ok, _} =
                LtiParams.create_or_update_lti_params(lti_params, user.id)

              # update user platform roles
              Accounts.update_user_platform_roles(
                user,
                PlatformRoles.get_roles_by_uris(lti_roles)
              )

              # context claim is considered optional according to IMS http://www.imsglobal.org/spec/lti/v1p3/#context-claim
              # safeguard against the case that context is missing
              case lti_params["https://purl.imsglobal.org/spec/lti/claim/context"] do
                nil ->
                  {_error_id, error_msg} =
                    Oli.Utils.log_error("context claim is missing from lti params")

                  throw(error_msg)

                context ->
                  # update section specifics - if one exists. Enroll the user and also update the section details
                  with {:ok, section} <- get_existing_section(lti_params) do
                    # transform lti_roles to a list only containing valid context roles (exclude all system and institution roles)
                    context_roles = ContextRoles.get_roles_by_uris(lti_roles)

                    # if a course section exists, ensure that this user has an enrollment in this section
                    enroll_user(user.id, section.id, context_roles)

                    # make sure section details are up to date
                    %{"title" => context_title} = context

                    {:ok, _section} =
                      update_section_details(context_title, section, lti_params, registration)
                  end

                  # sign current user in and redirect to home page
                  conn
                  |> UserAuth.create_session(user)
                  |> redirect(to: "/sections")
              end

            {:error, changeset} ->
              {_error_id, error_msg} =
                Oli.Utils.log_error("Failed to create or update user", changeset)

              throw(error_msg)
          end
      end
    end)
  end

  defp enroll_user(user_id, section_id, context_roles) do
    Sections.enroll(user_id, section_id, context_roles)
  end

  defp update_section_details(context_title, section, lti_params, registration) do
    Sections.update_section(section, %{
      title: context_title,
      grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
      line_items_service_url: AGS.get_line_items_url(lti_params, registration),
      nrps_enabled: NRPS.nrps_enabled?(lti_params),
      nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
    })
  end

  defp get_existing_section(lti_params) do
    case Sections.get_section_from_lti_params(lti_params) do
      nil -> nil
      section -> {:ok, section}
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

        %Oli.Lti.PlatformExternalTools.SectionResourceDeepLink{url: nil, custom: custom} ->
          {platform_instance.target_link_uri, maybe_add_custom_claims(custom)}

        %Oli.Lti.PlatformExternalTools.SectionResourceDeepLink{url: url, custom: custom} ->
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
    show_registration_page(conn, issuer, client_id, deployment_id)
  end

  defp handle_invalid_deployment(conn, _params, registration_id, deployment_id) do
    registration = Institutions.get_registration!(registration_id)

    show_registration_page(conn, registration.issuer, registration.client_id, deployment_id)
  end

  defp show_registration_page(conn, issuer, client_id, deployment_id) do
    case Oli.Institutions.get_pending_registration(issuer, client_id, deployment_id) do
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
