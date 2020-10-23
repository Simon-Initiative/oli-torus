defmodule Oli.Email do
  import Bamboo.Email
  use Bamboo.Phoenix, view: OliWeb.EmailView

  @spec welcome_author_email(String.t()) :: Bamboo.Email.t()
  def welcome_author_email(recipient_email) do
    base_email()
    |> to(recipient_email)
    |> subject("Welcome to Torus!")
    |> render("welcome.html", title: "Welcome to Torus!", preview_text: "Create, deliver and continuously improve courses using data-driven learning science")
    |> premail()
  end

  def base_email do
    from_email = Application.get_env(:oli, :email_from)
    email_reply_to = Application.get_env(:oli, :email_reply_to)

    new_email()
    |> from(from_email)
    |> put_header("Reply-To", email_reply_to)
    # render both email.html and email.text layouts using :email
    |> put_layout({OliWeb.LayoutView, :email})
  end

  def premail(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end
end
