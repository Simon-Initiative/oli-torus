defmodule OliWeb.LtiController do
  use OliWeb, :controller

  import Oli.Delivery.Lti.Provider

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Institution
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionRoles
  alias Oli.Grading.CanvasApi
  alias Oli.Lti_1p3

  @doc """
  Handles an LTI basic launch

  If the LTI launch is valid, this will redirect to the delivery controller, ensuring a user is
  enrolled in the section corresponding to the context_id

  If the LTI Launch is invalid, an invalid lti error page will be displayed
  """
  def basic_launch(conn, _params) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    scheme = System.get_env("LTI_PROTOCOL", scheme)
    port = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"
    url = "#{scheme}://#{conn.host}#{port}/lti/basic_launch"
    method = conn.method
    consumer_key = conn.body_params["oauth_consumer_key"]

    case Repo.get_by(Institution, consumer_key: consumer_key) do
      nil ->
        render(conn, "basic_launch_invalid.html", reason: "Institution with consumer_key '#{consumer_key}' does not exist")
      institution ->
        shared_secret = institution.shared_secret
        case validate_request(url, method, conn.body_params, shared_secret, DateTime.utc_now()) do
          { :ok } ->
            handle_valid_request(conn, institution)
          { :invalid, reason } ->
            handle_invalid_request(conn, reason)
        end
    end
  end

  defp handle_valid_request(conn, institution) do
    case Accounts.insert_or_update_lti_tool_consumer(%{
      info_product_family_code: conn.body_params["tool_consumer_info_product_family_code"],
      info_version: conn.body_params["tool_consumer_info_version"],
      instance_contact_email: conn.body_params["tool_consumer_instance_contact_email"],
      instance_guid: conn.body_params["tool_consumer_instance_guid"],
      instance_name: conn.body_params["tool_consumer_instance_name"],
      institution_id: institution.id,
    }) do
      {:ok, lti_tool_consumer} ->
        case Accounts.insert_or_update_user(%{
          email: conn.body_params["lis_person_contact_email_primary"],
          first_name: conn.body_params["lis_person_name_given"],
          last_name: conn.body_params["lis_person_name_family"],
          user_id: conn.body_params["user_id"],
          user_image: conn.body_params["user_image"],
          roles: conn.body_params["roles"],
          lti_tool_consumer_id: lti_tool_consumer.id,
          institution_id: institution.id,
        }) do
          {:ok, user } ->

            # Update section specifics - if one exists.  Enroll the
            # user and also update the section details
            with {:ok, section} <- get_existing_section(conn.body_params)
            do
              enroll_user(user.id, conn.body_params, section.id)
              update_section_details(conn.body_params, section)
            end

            # if account is linked to an author, sign them in
            conn = if user.author_id != nil do
              conn
              |> put_session(:current_author_id, user.author_id)
            else
              conn
            end

            # TODO: Remove when LTI 1.3 GS replaces canvas api for grade passback
            # For now, we must capture some canvas specific information for grade passback
            CanvasApi.handle_basic_launch(conn.body_params, user)

            # sign current user in and redirect to home page
            conn
            |> put_session(:current_user_id, user.id)
            |> put_session(:lti_params, conn.body_params)
            |> redirect(to: Routes.delivery_path(conn, :index))

            _ ->
              throw "Error creating user"
        end
      _ ->
        throw "Error creating LTI tool consumer"
    end
  end

  defp handle_invalid_request(conn, reason) do
    render(conn, "basic_launch_invalid.html", reason: reason)
  end

  # If a course section exists for the context_id, ensure that
  # this user has an enrollment in this section
  defp enroll_user(user_id, %{ "roles" => roles}, section_id) do

    section_role_id = case Oli.Delivery.Lti.parse_lti_role(roles) do
      :student -> SectionRoles.get_by_type("student").id
      _ -> SectionRoles.get_by_type("instructor").id
    end

    Sections.enroll(user_id, section_id, section_role_id)

  end

  defp update_section_details(%{ "context_title" => title}, section) do
    Sections.update_section(section, %{title: title})
  end

  defp get_existing_section(%{ "context_id" => context_id}) do
    case Sections.get_section_by(context_id: context_id) do
      nil -> nil
      section -> {:ok, section}
    end
  end

  ## LTI 1.3
  def login(conn, _params) do
    case Lti_1p3.OidcLogin.oidc_login_redirect_url(conn, "/lti/launch") do
      {:ok, conn, redirect_url} ->
        conn
        |> redirect(external: redirect_url)
      # {:error, error} ->
    end
  end

  def launch(conn, params) do
    IO.inspect params, label: "params"
    case Lti_1p3.LaunchValidation.validate(conn, &get_public_key/2) do
      {:ok, conn, lti_params} ->
        render(conn, "lti_test.html", lti_params: lti_params)
      {:error, reason} ->
        render(conn, "basic_launch_invalid.html", reason: reason)
    end
  end

  @spec get_public_key(%Lti_1p3.Registration{}, String.t()) :: {:ok, JOSE.JWK.t()}
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
