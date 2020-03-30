defmodule Oli.TestHelpers do
  alias Oli.Repo
  alias Oli.Accounts.Author
  alias Oli.Lti.HmacSHA1
  import Oli.Utils

  def author_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        email: "ironman#{System.unique_integer([:positive])}@example.com",
        first_name: "Tony",
        last_name: "Stark",
        token: "2u9dfh7979hfd",
        provider: "google",
        system_role_id: 1,
      })

    {:ok, author} =
      Author.changeset(%Author{}, params)
      |> Repo.insert()

    author
  end

  def url_from_conn(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    scheme = System.get_env("LTI_PROTOCOL", scheme)
    port = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"

    "#{scheme}://#{conn.host}#{port}/lti/basic_launch"
  end

  def build_lti_request(req_url, shared_secret, nonce) do
    lti_params = %{
      "oauth_consumer_key" => "60dc6375-5eeb-4475-8788-fb69e32153b6",
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_timestamp" => DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string,
      "oauth_nonce" => nonce,
      "oauth_version" => "1.0",
      "context_id" => "4dde05e8ca1973bcca9bffc13e1548820eee93a3",
      "context_label" => "Torus",
      "context_title" => "Torus Test",
      "ext_roles" => "urn:lti:instrole:ims/lis/Student,urn:lti:role:ims/lis/Learner,urn:lti:sysrole:ims/lis/User",
      "launch_presentation_document_target" => "iframe",
      "launch_presentation_locale" => "en",
      "launch_presentation_return_url" => "https://canvas.oli.cmu.edu/courses/1/external_content/success/external_tool_redirect",
      "lis_person_contact_email_primary" => "exampleuser@example.edu",
      "lis_person_name_family" => "User",
      "lis_person_name_full" => "Example User",
      "lis_person_name_given" => "Example",
      "lti_message_type" => "basic-lti-launch-request",
      "lti_version" => "LTI-1p0",
      "oauth_callback" => "about:blank",
      "resource_link_id" => "82f5cc6b61288d047fc5213547ac8fba4790bffa",
      "resource_link_title" => "Torus OLI",
      "roles" => "Learner",
      "tool_consumer_info_product_family_code" => "canvas",
      "tool_consumer_info_version" => "cloud",
      "tool_consumer_instance_contact_email" => "admin@canvas.oli.cmu.edu",
      "tool_consumer_instance_guid" => "8865aa05b4b79b64a91a86042e43af5ea8ae79eb.localhost:8900",
      "tool_consumer_instance_name" => "OLI Canvas Admin",
      "user_id" => "dc86d3e58c1025af0b2cce49205ad2cb1019d546",
      "user_image" => "https://canvas.oli.cmu.edu/images/messages/avatar-50.png",
    }

    oauth_signature = HmacSHA1.build_signature(
      req_url,
      "POST",
      unsafe_map_to_keyword_list(lti_params),
      shared_secret
    )

    Map.put(lti_params, "oauth_signature", oauth_signature)
  end

end
