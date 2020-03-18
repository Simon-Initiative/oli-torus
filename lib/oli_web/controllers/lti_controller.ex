defmodule OliWeb.LtiController do
  use OliWeb, :controller

  import Oli.Lti.Provider

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Institution
  import OliWeb.ErrorHelpers

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
        case validate_request(url, method, unsafe_map_to_keyword_list(conn.body_params), shared_secret) do
          { :ok } ->
            handle_valid_request(conn, institution)
          { :invalid, reason } ->
            handle_invalid_request(conn, reason)
        end
    end
  end

  def handle_valid_request(conn, institution) do
    author_params = %{
      email: conn.body_params["lis_person_contact_email_primary"],
      first_name: conn.body_params["lis_person_name_given"],
      last_name: conn.body_params["lis_person_name_family"],
      provider: "lti",
      email_verified: true,
      system_role_id: Accounts.SystemRole.role_id.author
    }

    # TODO: Check if author already exists with given email, then they can be given the option
    # to merge this account with the existing one
    if Accounts.author_with_email_exists?(author_params.email), do: throw "user with email already exists"

    case Accounts.create_author(author_params, ignore_required: [:last_name]) do
      {:ok, author} ->
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
              user_id: conn.body_params["user_id"],
              user_image: conn.body_params["user_image"],
              roles: conn.body_params["roles"],
              author: author.id,
              lti_tool_consumer: lti_tool_consumer.id,
            }) do
              {:ok, _author_details } ->
                render(conn, "basic_launch.html", institution: institution, author: author)
            end
          _ ->
            throw "Error creating LTI tool consumer"
        end
      {:error, changeset} ->
        throw "Error creating LTI user: " <> translate_all_changeset_errors(changeset)
    end
  end

  def handle_invalid_request(conn, reason) do
    render(conn, "basic_launch_invalid.html", reason: reason)
  end

  # Converts a map of LTI parameters to a keyword list.
  # This function is unsafe because it expects an atom to exist for each map key,
  # which makes it only safe for known LTI requests
  defp unsafe_map_to_keyword_list(map) do
    Enum.map(map, fn({key, value}) -> {String.to_atom(key), value} end)
  end

end
