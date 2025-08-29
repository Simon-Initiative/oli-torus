defmodule Oli.Email do
  use Phoenix.Swoosh,
    view: OliWeb.EmailView,
    layout: {OliWeb.LayoutView, :email}

  def help_desk_email(from_email, help_desk_email, subject, view, assigns) do
    base_email()
    |> reply_to(from_email)
    |> put_layout({OliWeb.LayoutView, :help_email})
    |> to(help_desk_email)
    |> subject(subject)
    |> render_body(view, assigns)
    |> html_text_body()
  end

  def create_text_email(recipient_email, subject, body) do
    base_email()
    |> to(recipient_email)
    |> subject(subject)
    |> text_body(body)
  end

  @doc """
  Creates a generic email with an html and text body.
  Returns a Swoosh.Email struct ready for delivery.

  ## Examples:
    iex> create_email("someone@example.com", "Example Email", :template, assigns)
    %Swoosh.Email{}
  """
  def create_email(recipient_email, subject, view, assigns) do
    base_email()
    |> to(recipient_email)
    |> subject(subject)
    |> render_body(view, assigns)
    |> html_text_body()
  end

  def base_email do
    from_email_name = Application.get_env(:oli, :email_from_name)
    from_email_address = Application.get_env(:oli, :email_from_address)
    email_reply_to = Application.get_env(:oli, :email_reply_to)

    new()
    |> from({from_email_name, from_email_address})
    |> reply_to(email_reply_to)
  end

  defp html_text_body(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end
end
