# Developer

### General Notes

- [bcrypt_elixir](https://github.com/riverrun/bcrypt_elixir) requires >1 CPU core to function. If you have only one core, on say a small VPS, your release will crash without giving a useful error message!! For a single core host, use Pbkdf2 instead of Bcrypt. See here for more on this: https://github.com/riverrun/comeonin/wiki/Deployment

## Access Genearted Emails in Development

When the system generates email in production, generally it will be handed to an email service such as Amazon SES. Any email service supported by Bamboo can be configured in config/prod.exs. Refer to the Bamboo and Pow docs to see a list of all supported email adapters and how to configure them https://hexdocs.pm/pow/configuring_mailer.html#content, https://hexdocs.pm/bamboo/readme.html

In development mode, the system will use the Bamboo.LocalAdapter mailer, which stores sent mail in memory and is accessible via web browser at `https://localhost/dev/sent_emails`. There is also a specific test adapter configured for unit testing.