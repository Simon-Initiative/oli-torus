# Developer

### General Notes

- [bcrypt_elixir](https://github.com/riverrun/bcrypt_elixir) requires >1 CPU core to function. If you have only one core, on say a small VPS, your release will crash without giving a useful error message!! For a single core host, use Pbkdf2 instead of Bcrypt. See here for more on this: https://github.com/riverrun/comeonin/wiki/Deployment