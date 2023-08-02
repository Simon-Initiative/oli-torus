defmodule Oli.Email do
  import Bamboo.Email
  use Bamboo.Phoenix, view: OliWeb.EmailView

  @spec invitation_email(String.t(), atom(), map()) :: Bamboo.Email.t()
  def invitation_email(recipient_email, :enrollment_invitation, assigns) do
    base_email()
    |> to(recipient_email)
    |> subject(
      "You were invited as #{if assigns.role == "instructor", do: "an instructor", else: "a student"} to \"#{assigns.section_title}\""
    )
    |> render(:enrollment_invitation, assigns)
    |> html_text_body()
  end

  def invitation_email(recipient_email, view, assigns) do
    base_email()
    |> to(recipient_email)
    |> subject("Collaborator Invitation")
    |> render(view, assigns)
    |> html_text_body()
  end

  @spec help_desk_email(String.t(), String.t(), String.t(), atom(), map()) ::
          Bamboo.Email.t()
  def help_desk_email(from_email, help_desk_email, subject, view, assigns) do
    base_email()
    |> put_header("Reply-To", from_email)
    |> put_layout({OliWeb.LayoutView, :help_email})
    |> to(help_desk_email)
    |> subject(subject)
    |> render(view, assigns)
    |> html_text_body()
  end

  @doc """
  Creates a generic email with an html and text body.
  Returns a Bamboo.Email struct ready for delivery.
  ## Examples:
    iex> create_email("someone@example.com", "Example Email", "template.html", assigns)
    %Bamboo.Email{}
  """
  @spec create_email(String.t(), String.t(), String.t(), map()) :: Bamboo.Email.t()
  def create_email(recipient_email, subject, view, assigns) do
    base_email()
    |> to(recipient_email)
    |> subject(subject)
    |> render(view, assigns)
    |> html_text_body()
  end

  def base_email do
    from_email_name = Application.get_env(:oli, :email_from_name)
    from_email_address = Application.get_env(:oli, :email_from_address)
    email_reply_to = Application.get_env(:oli, :email_reply_to)

    new_email()
    |> from({from_email_name, from_email_address})
    |> put_header("Reply-To", email_reply_to)
    # render both email.html and email.text layouts using :email
    |> put_layout({OliWeb.LayoutView, :email})
  end

  def html_text_body(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end
end
