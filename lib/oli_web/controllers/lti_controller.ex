defmodule OliWeb.LtiController do
  use OliWeb, :controller

  import Oli.Lti.Provider
  import Oli.Utils

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Institution

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
        case validate_request(url, method, unsafe_map_to_keyword_list(conn.body_params), shared_secret, DateTime.utc_now()) do
          { :ok } ->
            handle_valid_request(conn, institution)
          { :invalid, reason } ->
            handle_invalid_request(conn, reason)
        end
    end
  end

  def handle_valid_request(conn, institution) do
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
            conn
            |> put_session(:current_user_id, user.id)
            |> redirect(to: Routes.delivery_path(conn, :index))

            _ ->
              throw "Error creating user"
        end
      _ ->
        throw "Error creating LTI tool consumer"
    end
  end

  def handle_invalid_request(conn, reason) do
    render(conn, "basic_launch_invalid.html", reason: reason)
  end

end
