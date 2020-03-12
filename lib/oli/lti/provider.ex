defmodule Oli.Lti.Provider do
  alias Oli.Lti.HmacSHA1

  @type lti_message_params :: [
    lti_message_type: String.t, # "basic-lti-launch-request" | "ContentItemSelectionRequest",
    lti_version: String.t,   # version of the specification is being used
    resource_link_id: String.t,   # unique identifier that the TC guarantees will be unique

    resource_link_title: String.t | nil,   # title for the resource
    resource_link_description: String.t | nil,   # description of the link’s destination
    user_id: String.t | nil,       # uniquely identifies the user
    user_image: String.t | nil,    # URI for an image of the user who launches this request.
    roles: String.t | nil,         # comma-separated list of URN values for roles
    role_scope_mentor: String.t | nil,

    # information about the user who launches this request. (optional)
    lis_person_name_given: String.t | nil,
    lis_person_name_family: String.t | nil,
    lis_person_name_full: String.t | nil,
    lis_person_contact_email_primary: String.t | nil,

    context_id: String.t | nil,      # uniquely identifies the context that contains the link being launched
    context_type: String.t | nil,    # comma-separated list of URN values that identify the type of context
    context_title: String.t | nil,   # title of the context – it should be about the length of a line
    context_label: String.t | nil,   # label for the context – intended to fit in a column
    launch_presentation_locale: String.t | nil,
    launch_presentation_document_target: String.t | nil,
    launch_presentation_css_url: String.t | nil,
    launch_presentation_width: String.t | nil,
    launch_presentation_height: String.t | nil,
    launch_presentation_return_url: String.t | nil,
    tool_consumer_info_product_family_code: String.t | nil,
    tool_consumer_info_version: String.t | nil,
    tool_consumer_instance_guid: String.t | nil,
    tool_consumer_instance_name: String.t | nil,
    tool_consumer_instance_description: String.t | nil,
    tool_consumer_instance_url: String.t | nil,
    tool_consumer_instance_contact_email: String.t | nil,

    # learning information services
    lis_result_sourcedid: String.t| nil,
    lis_outcome_service_url: String.t | nil,
    lis_person_sourcedid: String.t | nil,
    lis_course_offering_sourcedid: String.t | nil,
    lis_course_section_sourcedid: String.t | nil,

    # security params
    oauth_consumer_key: String.t,
    oauth_signature: String.t,
    oauth_signature_method: String.t,
    oauth_timestamp: String.t,
    oauth_nonce: String.t,
    oauth_version: String.t,

    # lti extension params - https://www.edu-apps.org/extensions/content.html
    ext_content_return_types: String.t | nil,      # indicates that the consumer is capable of content extension
    ext_content_intended_use: String.t | nil,      # hint to the provider for how the content will be used
    ext_content_return_url: String.t | nil,        # url that the provider should redirect the user to
    ext_content_file_extensions: String.t | nil,   # comma separated list of the file extensions
  ]

  # @spec validate_request(String.t, String.t, lti_message_params, String.t) :: { :ok } | { :invalid, String.t } | { :error, any }
  def validate_request(host, method, body_params, shared_secret) do
    case validate_parameters(body_params) do
      { :ok } ->
        case validate_oauth(host, method, body_params, shared_secret) do
          { :ok } -> { :ok }
          { :invalid, reason } -> { :invalid, reason }
        end
      { :invalid, reason } -> { :invalid, reason }
    end
  end

  def validate_parameters(body_params) do
    # TODO: replace hardcoded supported versions with a configurable variable
    is_basic_launch = Keyword.get(body_params, :lti_message_type) === "basic-lti-launch-request"
    is_correct_version = Enum.member?(["LTI-1p0"], Keyword.get(body_params, :lti_version))
    has_resource_link_id = Keyword.get(body_params, :resource_link_id) !== nil

    if is_basic_launch && is_correct_version && has_resource_link_id do
      { :ok }
    else
      { :invalid, "Invalid LTI parameters"}
    end
  end

  @spec validate_oauth(String.t, String.t, lti_message_params, String.t) :: { :ok } | { :invalid, String.t}
  def validate_oauth(url, method, body_params, shared_secret) do
    req_signature = HmacSHA1.build_signature(
      url,
      method,
      body_params,
      shared_secret
    )

    if req_signature == Keyword.get(body_params, :oauth_signature) do
      { :ok }
    else
      { :invalid, "Invalid OAuth - Signature does not match"}
    end
  end

end
