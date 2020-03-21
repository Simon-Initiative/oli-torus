defmodule Oli.Lti.ProviderTest do
  alias Oli.Lti.Provider
  import Phoenix.ConnTest

  use OliWeb.ConnCase, async: true

  describe "validate_parameters" do

    test "returns false if body params is empty" do
      { :invalid, _reason } =  Provider.validate_parameters([])
    end

    test "return true if parameters are valid" do
      { :ok } = Provider.validate_parameters([
        lti_version: "LTI-1p0",
        resource_link_id: "some_resource_link_id",
        lti_message_type: "basic-lti-launch-request"
      ])
    end

    test "returns invalid if lti_version parameter is missing" do
      { :invalid, _reason } = Provider.validate_parameters([
        resource_link_id: "some_resource_link_id",
        lti_message_type: "basic-lti-launch-request"
      ])
    end

    test "returns invalid if resource_link_id parameter is missing" do
      { :invalid, _reason } = Provider.validate_parameters([
        lti_version: "LTI-1p0",
        lti_message_type: "basic-lti-launch-request"
      ])
    end

  end

  # NOTE: http://lti.tools/oauth/ is an excellent resource for
  # generating and verifying these signatures
  describe "validate_oauth" do
    test "successfully validates an oauth request" do
      { :ok } = Provider.validate_oauth(
        "https://someurl.com/",
        "POST",
        [
          oauth_consumer_key: "consumer_key",
          oauth_nonce: "nonce",
          oauth_signature_method: "HMAC-SHA1",
          oauth_timestamp: "0",
          oauth_version: "1.0",
          oauth_signature: "8vGuVoSKBBVUL+ZxC8Du7Rtkbqk=",
          custom_param1: "value1"
        ],
        "secret",
        DateTime.from_unix!(0)
      )
    end

    test "fails when oauth signature is invalid" do
      { :invalid, _reason } = Provider.validate_oauth(
        "https://someurl.com/",
        "POST",
        [
          oauth_consumer_key: "consumer_key",
          oauth_nonce: "nonce",
          oauth_signature_method: "HMAC-SHA1",
          oauth_timestamp: "0",
          oauth_version: "1.0",
          oauth_signature: "notavalidsignature=",
          custom_param1: "value1"
        ],
        "secret",
        DateTime.from_unix!(0)
      )
    end
  end

  describe "validate_request" do
    test "successfully validates a valid request" do
      { :ok } = Provider.validate_request(
        "https://someurl.com/",
        "POST",
        [
          lti_version: "LTI-1p0",
          resource_link_id: "some_resource_link_id",
          lti_message_type: "basic-lti-launch-request",
          oauth_consumer_key: "consumer_key",
          oauth_nonce: "nonce",
          oauth_signature_method: "HMAC-SHA1",
          oauth_timestamp: "0",
          oauth_version: "1.0",
          oauth_signature: "Hra/KZuAi95CCMHVHR5LjFpWQhA=",
          custom_param1: "value1"
        ],
        "secret",
        DateTime.from_unix!(0)
      )
    end

    test "fails when request is invalid" do
      { :invalid, _reason } = Provider.validate_request(
        "https://someurl.com/",
        "POST",
        [
          lti_version: "LTI-1p0",
          resource_link_id: "some_resource_link_id",
          oauth_consumer_key: "consumer_key",
          oauth_nonce: "nonce",
          oauth_signature_method: "HMAC-SHA1",
          oauth_timestamp: "0",
          oauth_version: "1.0",
          oauth_signature: "notavalidsignature=",
          custom_param1: "value1"
        ],
        "secret",
        DateTime.from_unix!(0)
      )
    end
  end
end
