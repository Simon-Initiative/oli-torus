# Miscelleanous

## General Notes

- [bcrypt_elixir](https://github.com/riverrun/bcrypt_elixir) requires >1 CPU core to function. If you have only one core, on say a small VPS, your release will crash without giving a useful error message!! For a single core host, use Pbkdf2 instead of Bcrypt. See here for more on this: https://github.com/riverrun/comeonin/wiki/Deployment
- Link account using social login will not work out of the box in development mode! This is because you must configure an exact url with the OAuth provider, and therefore a local ngrok tunnel address will not work. If you really need this to work, you can configure your OAuth provider with your temporary ngrok address e.g. `https://163400959f6a.ngrok.io/auth/google/link/callback`. Be sure to also set your HOST in oli.env to your ngrok address as well (e.g. `HOST=https://163400959f6a.ngrok.io`) or else you will be redirected to localhost by default after login and the user session will not be present for linking, because it was stored in the session for the ngrok address. Because of this complexity, it is recommended to simply use an email account to link accounts, which does not experience this issue.

## Access Generated Emails in Development

When the system generates email in production, generally it will be handed to an email service such as Amazon SES. Any email service supported by Swoosh can be configured in config/prod.exs. Refer to the Swoosh docs to see a list of all supported email adapters and how to configure them [https://hexdocs.pm/swoosh/Swoosh.html](https://hexdocs.pm/swoosh/Swoosh.html).

In development mode, the system will use the Swoosh.Adapters.Local mailer, which stores sent mail in memory and is accessible via web browser at `https://localhost/dev/mailbox`. There is also a specific test adapter configured for unit testing.

## Create Registrations from seed

To ease the burden of creating a new registration after every database reset, there is the option to automatically create LTI registrations
attached to the default institution in dev environment by creating a registrations.json file in the project root.

Example:

```
[{
  "issuer": "https://canvas.oli.cmu.edu",
  "client_id": "XXXXXXXXXXXXX",
  "key_set_url": "https://canvas.oli.cmu.edu/api/lti/security/jwks",
  "auth_token_url": "https://canvas.oli.cmu.edu/login/oauth2/token",
  "auth_login_url": "https://canvas.oli.cmu.edu/api/lti/authorize_redirect",
  "auth_server": "https://canvas.oli.cmu.edu/login/oauth2/token"
}]
```

With this file, now when you run `mix ecto.seed` or `mix ecto.reset`, a registration with these details will be created for you.
