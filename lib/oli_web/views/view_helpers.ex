defmodule OliWeb.ViewHelpers do
  use Phoenix.HTML
  use Phoenix.Component

  import Oli.Branding
  import Oli.Utils, only: [value_or: 2]

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Branding.Brand

  def brand_logo(%{brand: %Brand{}} = assigns) do
    ~H"""
      <img src={@brand.logo} class={[value_or(assigns[:class], ""), "inline-block dark:hidden"]} alt={@brand.name}>
      <img src={value_or(@brand.logo_dark, @brand.logo)} class={[value_or(assigns[:class], ""), "hidden dark:inline-block"]}  alt={@brand.name}>
    """
  end

  def brand_logo(assigns) do
    ~H"""
      <img src={brand_logo_url(assigns[:section])} class={[value_or(assigns[:class], ""), "inline-block dark:hidden"]} alt={brand_name(assigns[:section])}>
      <img src={brand_logo_url_dark(assigns[:section])} class={[value_or(assigns[:class], ""), "hidden dark:inline-block"]}  alt={brand_name(assigns[:section])}>
    """
  end

  def preview_mode(%{assigns: assigns} = _conn) do
    Map.get(assigns, :preview_mode, false)
  end

  @doc """
  Renders a link with text and an external icon which opens in a new tab
  """
  def external_link(text, opts \\ []) do
    link Keyword.merge([target: "_blank"], opts) do
      [text, content_tag("i", "", class: "fas fa-external-link-alt ml-1")]
    end
  end

  def is_section_instructor_or_admin?(section_slug, user_or_author) do
    Sections.is_instructor?(user_or_author, section_slug) ||
      Sections.is_admin?(user_or_author, section_slug) ||
      Accounts.is_admin?(user_or_author)
  end

  def is_section_instructor?(section_slug, user) do
    Sections.is_instructor?(user, section_slug)
  end

  def is_independent_instructor?(user), do: Sections.is_independent_instructor?(user)

  def is_admin?(section_slug, user) do
    Sections.is_admin?(user, section_slug)
  end

  @doc """
  Returns true if a user is signed in
  """
  def user_signed_in?(conn) do
    conn.assigns[:current_user]
  end

  @doc """
  Returns true if a author is signed in
  """
  def author_signed_in?(conn) do
    conn.assigns[:current_author]
  end

  def redirect_with_error(conn, error_url, error) do
    conn
    |> Phoenix.Controller.redirect(external: "#{error_url}?error=#{error}")
    |> Plug.Conn.halt()
  end
end
