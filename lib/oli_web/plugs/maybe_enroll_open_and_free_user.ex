defmodule Oli.Plugs.MaybeEnrollOpenAndFreeUser do
  import Oli.Utils
  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias OliWeb.Common.LtiSession
  alias OliWeb.Router.Helpers, as: Routes
  alias Lti_1p3.Tool.PlatformRoles

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"section_slug" => section_slug} <- conn.path_params,
         {:ok, section} <- Sections.get_section_by(slug: section_slug, open_and_free: true) |> trap_nil
    do
      case Pow.Plug.current_user(conn) do
        nil ->
          case create_open_and_free_user() do
            {:ok, user} ->
              maybe_enroll_user(conn, user, section)

            _ ->
              throw "Error creating open and free user"
          end
        user ->
          maybe_enroll_user(conn, user, section)
      end
    else
      _ ->
        conn
    end
  end

  defp create_open_and_free_user() do
    {:ok, user} = Accounts.create_user(%{
      # generate a unique sub identifier which is also used so a user can access
      # their progress in the future or using a different browser
      sub: UUID.uuid4(),
    })

    Accounts.update_user_platform_roles(user, [
      PlatformRoles.get_role(:institution_learner),
    ])
  end

  defp maybe_enroll_user(conn, user, section) do
    # create or update lti_params for open and free user
    params = open_and_free_lti_params(user, section)
    exp = Timex.now |> Timex.add(Timex.Duration.from_weeks(52))
    {:ok, %Lti_1p3.Tool.LtiParams{}} = %Lti_1p3.Tool.LtiParams{key: user.sub, params: params, exp: exp}
      |> Lti_1p3.DataProviders.EctoProvider.create_or_update_lti_params()

    conn = conn
      |> LtiSession.put_user_params(user.sub)
      |> LtiSession.put_section_params(section.slug, user.sub)

    if Sections.is_enrolled?(user.id, section.slug) do
      # user is already enrolled
      conn
    else
      # enroll new open and free user in this section as a student/learner
      context_roles = params["https://purl.imsglobal.org/spec/lti/claim/roles"]
        |> Lti_1p3.Tool.ContextRoles.get_roles_by_uris()

      Sections.enroll(user.id, section.id, context_roles)

      conn
      |> Phoenix.Controller.put_flash(:info, "You've been enrolled! Save this URL to login: #{Routes.delivery_url(conn, :login, user.sub)}")
    end
    |> OliWeb.Pow.PowHelpers.use_pow_config(:user)
    |> Pow.Plug.create(user)
  end

  # creates mock lti_params for open and free user which are used to power delivery,
  # we will just use the user's sub uuid as the key since it is guaranteed to be unique
  defp open_and_free_lti_params(user, section) do
    %{
      "sub" => user.sub,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
          "id" => section.context_id,
          "title" => section.title,
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student",
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      ],
      "https://oli.cmu.edu/session" => %{
        "open_and_free" => true,
      }
    }
  end
end
