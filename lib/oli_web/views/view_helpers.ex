defmodule OliWeb.ViewHelpers do
  use Phoenix.HTML
  use Phoenix.Component

  import Oli.Branding
  import Oli.Utils, only: [value_or: 2]

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Branding.Brand

  def brand_logo(%{brand: %Brand{name: name, logo: logo, logo_dark: logo_dark}} = assigns) do
    ~H"""
      <img src={logo} height="40" class={["d-dark-none", assigns[:class]]} alt={name}>
      <img src={value_or(logo_dark, logo)} height="40" class={["d-light-none", assigns[:class]]}  alt={name}>
    """
  end

  def brand_logo(assigns) do
    ~H"""
      <img src={brand_logo_url(assigns[:section])} height="40" class={["d-dark-none", assigns[:class]]} alt={brand_name(assigns[:section])}>
      <img src={brand_logo_url_dark( assigns[:section])} height="40" class={["d-light-none", assigns[:class]]}  alt={brand_name(assigns[:section])}>
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
      [text, content_tag("i", "", class: "las la-external-link-alt ml-1")]
    end
  end

  def is_section_instructor_or_admin?(section_slug, user) do
    Sections.is_instructor?(user, section_slug) || Sections.is_admin?(user, section_slug)
  end

  def is_section_instructor?(section_slug, user) do
    Sections.is_instructor?(user, section_slug)
  end

  def is_admin?(section_slug, user) do
    Sections.is_admin?(user, section_slug)
  end

  def maybe_section_slug(conn) do
    case conn.assigns[:section] do
      %Section{slug: slug} ->
        slug

      _ ->
        ""
    end
  end

  def delivery_breadcrumbs?(%{assigns: assigns} = _conn),
    do:
      Map.has_key?(assigns, :delivery_breadcrumb) and
        Map.get(assigns, :delivery_breadcrumb, false) and
        (Map.has_key?(assigns, :breadcrumbs) and length(Map.get(assigns, :breadcrumbs, [])) > 0)

  def redirect_with_error(conn, error_url, error) do
    conn
    |> Phoenix.Controller.redirect(external: "#{error_url}?error=#{error}")
    |> Plug.Conn.halt()
  end
end
