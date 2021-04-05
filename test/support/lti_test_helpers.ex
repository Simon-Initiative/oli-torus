defmodule Oli.Lti_1p3.TestHelpers do
  def all_default_claims() do
    %{}
    |> Map.merge(security_detail_data())
    |> Map.merge(user_detail_data())
    |> Map.merge(claims_data())
    |> Map.merge(example_extension_data())
  end

  def security_detail_data() do
    %{
      "iss" => "https://lti-ri.imsglobal.org",
      "sub" => "a73d59affc5b2c4cd493",
      "aud" => "12345",
      "exp" => Timex.now() |> Timex.add(Timex.Duration.from_minutes(5)) |> Timex.to_unix(),
      "iat" => Timex.now() |> Timex.to_unix(),
      "nonce" => UUID.uuid4()
    }
  end

  def user_detail_data() do
    %{
      "given_name" => "Chelsea",
      "family_name" => "Conroy",
      "middle_name" => "Reichel",
      "picture" => "http://example.org/Chelsea.jpg",
      "email" => "Chelsea.Conroy@example.org",
      "name" => "Chelsea Reichel Conroy",
      "locale" => "en-US"
    }
  end

  def claims_data() do
    %{
      "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint" => %{
        "lineitems" => "https://lti-ri.imsglobal.org/platforms/1237/contexts/10337/line_items",
        "scope" => [
          "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
          "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly"
        ]
      },
      "https://purl.imsglobal.org/spec/lti-ces/claim/caliper-endpoint-service" => %{
        "caliper_endpoint_url" => "https://lti-ri.imsglobal.org/platforms/1237/sensors",
        "caliper_federated_session_id" => "urn:uuid:7bec5956c5297eacf382",
        "scopes" => ["https://purl.imsglobal.org/spec/lti-ces/v1p0/scope/send"]
      },
      "https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice" => %{
        "context_memberships_url" =>
          "https://lti-ri.imsglobal.org/platforms/1237/contexts/10337/memberships",
        "service_versions" => ["2.0"]
      },
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "10337",
        "label" => "My Course",
        "title" => "My Course",
        "type" => ["Course"]
      },
      "https://purl.imsglobal.org/spec/lti/claim/custom" => %{
        "myCustomValue" => "123"
      },
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => "1",
      "https://purl.imsglobal.org/spec/lti/claim/launch_presentation" => %{
        "document_target" => "iframe",
        "height" => 320,
        "return_url" => "https://lti-ri.imsglobal.org/platforms/1237/returns",
        "width" => 240
      },
      "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiResourceLinkRequest",
      "https://purl.imsglobal.org/spec/lti/claim/resource_link" => %{
        "description" => "my course",
        "id" => "20052",
        "title" => "My Course"
      },
      "https://purl.imsglobal.org/spec/lti/claim/role_scope_mentor" => ["a62c52c02ba262003f5e"],
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
        "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student",
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Mentor"
      ],
      "https://purl.imsglobal.org/spec/lti/claim/target_link_uri" =>
        "https://lti-ri.imsglobal.org/lti/tools/1193/launches",
      "https://purl.imsglobal.org/spec/lti/claim/tool_platform" => %{
        "contact_email" => "",
        "description" => "",
        "guid" => 1237,
        "name" => "lti-test",
        "product_family_code" => "",
        "url" => "",
        "version" => "1.0"
      },
      "https://purl.imsglobal.org/spec/lti/claim/version" => "1.3.0"
    }
  end

  def example_extension_data() do
    %{
      "https://www.example.com/extension" => %{"color" => "violet"}
    }
  end
end
