defmodule OliWeb.Pow.Mailer do
  use Pow.Phoenix.Mailer
  use Bamboo.Mailer, otp_app: :oli

  import Bamboo.Email

  alias Oli.Email

  @impl true
  def cast(%{user: user, subject: subject, text: _text, html: html}) do
    Email.base_email()
    |> to(user.email)
    |> subject(subject)
    |> html_body(Premailex.to_inline_css(html))
    |> text_body(Premailex.to_text(html))
  end

  @impl true
  def process(email) do
    # An asynchronous process should be used here to prevent enumeration
    # attacks. Synchronous e-mail delivery can reveal whether a user already
    # exists in the system or not.

    deliver_later(email)
  end
end
