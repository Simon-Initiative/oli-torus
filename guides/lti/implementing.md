# LTI 1.3

## LTI 1.3 Launch Overview

This is a summary of the LTI 1.3 handshake outlined in the IMS Security Framework 1.0 Specification ([5.1 Platform-Originating Messages](https://www.imsglobal.org/spec/security/v1p0/#platform-originating-messages)) geared toward elixir developers who wish to implement LTI 1.3 in their apps. This page assumes that both the tool and platform have been registered with each other.

Remember that registering requires a tool and platform to store important details about each other, such as:

**Example tool details** registered with the platform:

```elixir
client_id: "1000000000001"
keyset_url: "https://tool.example.edu/.well-known/jwks.json"
oidc_login_url: "https://tool.example.edu/login"
redirect_uris: "https://tool.example.edu/launch"
target_link_ui: "https://tool.example.edu/launch"
```

**Example platform details** registered with the tool:

```elixir
issuer: "https://platform.example.edu"
client_id: "1000000000001"
key_set_url: "https://platform.example.edu/.well-known/jwks.json"
auth_token_url: "https://platform.example.edu/access_tokens"
auth_login_url: "https://platform.example.edu/authorize_redirect"
```

This registration process happens out-of-band before the LTI launch itself can be performed. Typically this information is exchanged between two parties through some external form of communication (e.g. email) or automatic registration and approval process.

### LTI 1.3 Process

![LTI 1.3 Launch Flow](https://www.imsglobal.org/sites/default/files/specs/images/security/1p0/fig5p2-oidcflowv1.jpg)

### Step 1: Third-party Initiated Login

https://www.imsglobal.org/spec/security/v1p0/#step-1-third-party-initiated-login

An LTI launch begins with a form submission (GET or POST) from a platform webpage. The **platform** crafts the form using the pre-registered tool configuration and platform details. The form can either target the current window by default or an iframe embedded in the page. For example, this form will target the iframe below it:

_controller.ex_

```elixir
launch_params = %{
  # client_id must match the value registered with the tool
  client_id: "1000000000001",

  # issuer value associated with the plaform
  iss: "https://platform.example.edu",

  # tool OIDC login path, the destination this request will be sent to
  oidc_login_url: "https://tool.example.edu/login",

  # the location of the requested LTI resource
  target_link_uri: "https://tool.example.edu/launch",

  # unique token used later by the platform to associate the request with this user session
  login_hint: "ac5cdc6e-1dd2-97f2-e2c8-0d4236e9b092",
}

render(conn, "lti_launch.html", launch_params: launch_params)
```

_lti_launch.html.eex_

```html
<form
  action="<%= @launch_params.oidc_login_url %>"
  method="post"
  target="tool_content"
>
  <input type="hidden" name="iss" id="iss" value="<%= @launch_params.iss %>" />
  <input
    type="hidden"
    name="login_hint"
    id="login_hint"
    value="<%= @launch_params.login_hint %>"
  />
  <input
    type="hidden"
    name="client_id"
    id="client_id"
    value="<%= @launch_params.client_id %>"
  />
  <input
    type="hidden"
    name="target_link_uri"
    id="target_link_uri"
    value="<%= @launch_params.target_link_uri %>"
  />

  <button type="submit">Launch LTI 1.3 Tool</button>
</form>

<iframe src="about:blank" name="tool_content" title="Tool Content"></iframe>
```

When a user clicks the "Launch LTI 1.3 Tool" button the form request will be sent to the tool's OIDC login endpoint and the LTI 1.3 handshake will begin.

### Step 2: Authentication Request

https://www.imsglobal.org/spec/security/v1p0/#step-2-authentication-request

When the request is recieved, the **tool** will validate the issuer and client_id match the registered platform, validate the login_hint param is present and issue a redirect to the platform's OIDC (OpenID Connect) endpoint to authenticate the user.

If validation is successful, the tool will craft the OIDC request with the following parameters:

```elixir
%{
  # OIDC and LTI 1.3 required params
  "scope" => "openid",
  "response_type" => "id_token",
  "response_mode" => "form_post",
  "prompt" => "none",

  # client_id that was given by POST params, also associated with the platform registration
  "client_id" => "some-client-id",

  # the tool url to redirect back to after successful login
  "redirect_uri" => "some-redirect_uri",

  # unique token associated with this request and used later to prevent CSRF
  "state" => "some-unique-token",

  # unique identifier cached by the platform to prevent replay attacks
  "nonce" => "some-unique-nonce",

  # opaque string used by the platform to validate the user session associated with the request
  "login_hint" => "some-login-hint",
}
```

For example, the final request using GET to the platform will look something like:
`GET /authorize_redirect?scope=openid&response_type=id_token&... etc.`

### Step 3: Authentication Response

https://www.imsglobal.org/spec/security/v1p0/#step-3-authentication-response

The **platform** will recieve the authorize_redirect request from the tool and it will validate the required OIDC params are present, validate the login_hint is associated with the current user session, validate the client_id is associated with a registered tool, validate the redirect_url matches one of the registered urls, and finally validate the nonce has not been used before. If valid, the platform will issue one final POST request to the tool's specified redirect_uri with the recieved state token and an id_token JWT containing the LTI 1.3 claims such as user details, context info, and any other LTI specific or custom claims that may be supported by the platform.

Here is an example of the LTI params within the id_token JWT. [Full example resource link request](http://www.imsglobal.org/spec/lti/v1p3/#examplelinkrequest).

```elixir
%{
  # security claims
  "iss" => "https://platform.example.edu",
  "sub" => "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
  "aud" => ["962fa4d8-bcbf-49a0-94b2-2de05ad274af"],
  "exp" => 1510185728,
  "iat" => 1510185228,
  "azp" => "962fa4d8-bcbf-49a0-94b2-2de05ad274af",
  "nonce" => "fc5fdc6d-5dd6-47f4-b2c9-5d1216e9b771",

  # user details claims
  "name" => "Ms Jane Marie Doe",
  "given_name" => "Jane",
  "family_name" => "Doe",
  "middle_name" => "Marie",
  "picture" => "https://platform.example.edu/jane.jpg",
  "email" => "jane@platform.example.edu",
  "locale" => "en-US",

  # LTI claims
  "https://purl.imsglobal.org/spec/lti/claim/deployment_id":
    "07940580-b309-415e-a37c-914d387c1150",
  "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiResourceLinkRequest",
  "https://purl.imsglobal.org/spec/lti/claim/version" => "1.3.0",
  "https://purl.imsglobal.org/spec/lti/claim/roles" => [
    "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student",
    "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
    "http://purl.imsglobal.org/vocab/lis/v2/membership#Mentor"
  ],
  "https://purl.imsglobal.org/spec/lti/claim/role_scope_mentor" => [
    "fad5fb29-a91c-770-3c110-1e687120efd9",
    "5d7373de-c76c-e2b-01214-69e487e2bd33",
    "d779cfd4-bc7b-019-9bf1a-04bf1915d4d0"
  ],
  "https://purl.imsglobal.org/spec/lti/claim/context" => {
      "id" => "c1d887f0-a1a3-4bca-ae25-c375edcc131a",
      "label" => "ECON 1010",
      "title" => "Economics as a Social Science",
      "type" => ["http://purl.imsglobal.org/vocab/lis/v2/course#CourseOffering"]
  },
  "https://purl.imsglobal.org/spec/lti/claim/resource_link" => {
      "id" => "200d101f-2c14-434a-a0f3-57c2a42369fd",
      "description" => "Assignment to introduce who you are",
      "title" => "Introduction Assignment"
  },
  "https://purl.imsglobal.org/spec/lti/claim/tool_platform" => {
      "guid" => "ex/48bbb541-ce55-456e-8b7d-ebc59a38d435",
      "contact_email" => "support@platform.example.edu",
      "description" => "An Example Tool Platform",
      "name" => "Example Tool Platform",
      "url" => "https://platform.example.edu",
      "product_family_code" => "ExamplePlatformVendor-Product",
      "version" => "1.0"
  },
  "https://purl.imsglobal.org/spec/lti/claim/target_link_uri":
      "https://tool.example.com/lti/48320/ruix8782rs",
  "https://purl.imsglobal.org/spec/lti/claim/launch_presentation" => {
      "document_target" => "iframe",
      "height" => 320,
      "width" => 240,
      "return_url" => "https://platform.example.edu/terms/201601/courses/7/sections/1/resources/2"
  },
  "https://purl.imsglobal.org/spec/lti/claim/lis" => {
      "person_sourcedid" => "example.edu:71ee7e42-f6d2-414a-80db-b69ac2defd4",
      "course_offering_sourcedid" => "example.edu:SI182-F16",
      "course_section_sourcedid" => "example.edu:SI182-001-F16"
  },

  # additional custom claims
  "https://purl.imsglobal.org/spec/lti/claim/custom" => {
    "xstart" => "2017-04-21T01:00:00Z",
    "request_url" => "https://tool.com/link/123"
  },

  # additional extensions claims
  "http://www.ExamplePlatformVendor.com/session" => {
      "id" => "89023sj890dju080"
  }
}
```

These params are encoded and signed as a JWT using RSA256 and the platform's private JWK, which can later be verfied by the tool using the platforms publicly accessible JWK.

This redirect POST can be accomplished by rendering an html form and (if enabled) using javascript to submit on the user's behalf.

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>You are being redirected...</title>
  </head>
  <body>
    <div>You are being redirected...</div>
    <form name="post_redirect" action="<%= @redirect_uri %>" method="post">
      <input type="hidden" name="state" value="<%= @state %>" />
      <input type="hidden" name="id_token" value="<%= @id_token %>" />

      <noscript>
        <input type="submit" value="Click here to continue" />
      </noscript>
    </form>

    <script type="text/javascript">
      window.onload = function () {
        document.getElementsByName("post_redirect")[0].style.display = "none";
        document.forms["post_redirect"].submit();
      };
    </script>
  </body>
</html>
```

### Step 4: Resource is displayed

https://www.imsglobal.org/spec/security/v1p0/#step-4-resource-is-displayed

Finally, if all validations have passed and the launch was successful, the LTI 1.3 resource will be displayed in the user's browser.

### References and Useful Links

- Learning Tools Interoperability Core Specification - [http://www.imsglobal.org/spec/lti/v1p3/](http://www.imsglobal.org/spec/lti/v1p3/)
- IMS Security Framework - [https://www.imsglobal.org/spec/security/v1p0](https://www.imsglobal.org/spec/security/v1p0)
- Canvas Platform Implementaion (authentication_controller.rb) - [https://github.com/instructure/canvas-lms/blob/master/app/controllers/lti/ims/authentication_controller.rb](https://github.com/instructure/canvas-lms/blob/master/app/controllers/lti/ims/authentication_controller.rb)
- IMS PHP Tool Library [https://github.com/IMSGlobal/lti-1-3-php-library](https://github.com/IMSGlobal/lti-1-3-php-library)
