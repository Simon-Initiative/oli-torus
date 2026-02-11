defmodule Oli.Email do
  use Phoenix.Swoosh,
    view: OliWeb.EmailView,
    layout: {OliWeb.LayoutView, :email}

  @doc """
  Creates a help desk email where the user is the initiator.
  Sets reply_to to the user's email so replies go back to them.
  Note: We keep the default FROM address (from base_email) to ensure compatibility
  with email providers like Amazon SES that require verified sender addresses.
  """
  def help_desk_email(user_name, user_email, help_desk_email, subject, view, assigns) do
    base_email()
    |> reply_to({user_name, user_email})
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

  @doc """
  Creates a base email with default from address and optional Errors-To/Return-Path headers.
  Does NOT set reply_to by default - specific email types should set this if needed.
  """
  def base_email do
    from_email_name = Application.get_env(:oli, :email_from_name)
    from_email_address = Application.get_env(:oli, :email_from_address)
    errors_to_address = Application.get_env(:oli, :email_errors_to_address)
    return_path_address = Application.get_env(:oli, :email_return_path_address)

    new()
    |> from({from_email_name, from_email_address})
    |> maybe_header("Errors-To", errors_to_address)
    |> maybe_header("Return-Path", return_path_address)
  end

  defp maybe_header(email, _name, nil), do: email
  defp maybe_header(email, _name, ""), do: email
  defp maybe_header(email, name, value), do: header(email, name, value)

  @doc """
  Sets reply_to only if the value is not nil or empty.
  """
  def maybe_reply_to(email, nil), do: email
  def maybe_reply_to(email, ""), do: email
  def maybe_reply_to(email, value), do: reply_to(email, value)

  @doc """
  Sets from only if the value is not nil or empty.
  """
  def maybe_from(email, nil), do: email
  def maybe_from(email, ""), do: email
  def maybe_from(email, value), do: from(email, value)

  defp html_text_body(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end
end
