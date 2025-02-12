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
    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]

    Oli.Repo.transaction(fn ->
      with {institution, registration, _deployment} <-
             Institutions.get_institution_registration_deployment(
               issuer,
               client_id,
               deployment_id
             ),
           {:ok, user} <-
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
             ),
           {:ok, _} <- LtiParams.create_or_update_lti_params(lti_params, user.id),
           {:ok, user} <-
             Accounts.update_user_platform_roles(
               user,
               PlatformRoles.get_roles_by_uris(lti_roles)
             ) do
        # Attempt to find an existing section that matches this context
        case Sections.get_section_from_lti_params(lti_params) do
          nil ->
            # A section has not been created for this context yet
            if can_configure_section?(lti_roles) do
              conn
              |> redirect(to: ~p"/sections/lti/new")
            else
              conn
              |> render("course_not_configured.html")
            end

          section ->
            # If a course section exists, ensure that this user has an enrollment in this section
            # with the appropriate roles
            context_roles = ContextRoles.get_roles_by_uris(lti_roles)
            Sections.enroll(user.id, section.id, context_roles)

            # Update section LTI details
            Sections.update_section(section, %{
              grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
              line_items_service_url: AGS.get_line_items_url(lti_params, registration),
              nrps_enabled: NRPS.nrps_enabled?(lti_params),
              nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
            })

            if can_configure_section?(lti_roles) do
              # Redirect to instructor dashboard
              conn
              |> redirect(to: ~p"/sections/#{section.slug}/manage")
            else
              # Redirect to student section view
              conn
              |> redirect(to: ~p"/sections/#{section.slug}")
            end
        end
      else
        error ->
          Logger.error("Failed to handle valid LTI 1.3 launch: #{Kernel.inspect(error)}")

          conn
          |> render("lti_error.html", reason: "Failed to handle valid LTI 1.3 launch")
      end
    end)
  end

  def can_configure_section?(lti_roles) do
    # allow section configuration if user has any of the allowed roles
    allow_configure_section_roles =
      [
        PlatformRoles.get_role(:system_administrator).uri,
        PlatformRoles.get_role(:institution_administrator).uri,
        ContextRoles.get_role(:context_administrator).uri,
        ContextRoles.get_role(:context_instructor).uri
      ]

    MapSet.intersection(
      MapSet.new(lti_roles),
      MapSet.new(allow_configure_section_roles)
    )
    |> MapSet.size() > 0
  end
end
