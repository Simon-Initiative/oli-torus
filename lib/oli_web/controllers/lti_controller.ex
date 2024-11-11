defmodule OliWeb.LtiController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  import Oli.Utils

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
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles
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
        handle_valid_lti_1p3_launch(conn, lti_params)

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

  def test(conn, params) do
    session_state = Plug.Conn.get_session(conn, "state")

    case Lti_1p3.Tool.LaunchValidation.validate(params, session_state) do
      {:ok, lti_params, _cache_key} ->
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

      %Lti_1p3.Platform.LoginHint{context: context} ->
        current_user =
          case context do
            "author" ->
              conn.assigns[:current_author]

            _ ->
              conn.assigns[:current_user]
          end

        issuer = Oli.Utils.get_base_url()
        # TODO: add multiple deployment support
        # for now, just use a single deployment with a static deployment_id
        deployment_id = "1"

        case Lti_1p3.Platform.AuthorizationRedirect.authorize_redirect(
               params,
               current_user,
               issuer,
               deployment_id
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

  def jwks(conn, _params) do
    conn
    |> json(Lti_1p3.get_all_public_keys())
  end

  def access_tokens(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{
      error: "NOT IMPLEMENTED"
    })
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

  defp handle_valid_lti_1p3_launch(conn, lti_params) do
    issuer = lti_params["iss"]
    client_id = LtiParams.peek_client_id(lti_params)
    deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]

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
                 address: lti_params["address"]
               },
               institution.id
             ) do
          {:ok, user} ->
            # update lti params and session to be associated with the current lms user
            {:ok, _} =
              LtiParams.create_or_update_lti_params(lti_params, user.id)

            # update user platform roles
            Accounts.update_user_platform_roles(user, PlatformRoles.get_roles_by_uris(lti_roles))

            # context claim is considered optional according to IMS http://www.imsglobal.org/spec/lti/v1p3/#context-claim
            # safeguard against the case that context is missing
            case lti_params["https://purl.imsglobal.org/spec/lti/claim/context"] do
              nil ->
                {_error_id, error_msg} = log_error("context claim is missing from lti params")

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
                |> UserAuth.log_in_user(user, %{"request_path" => "/course"})
            end

          {:error, changeset} ->
            {_error_id, error_msg} = log_error("Failed to create or update user", changeset)

            throw(error_msg)
        end
    end
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
end
