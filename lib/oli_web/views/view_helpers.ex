defmodule OliWeb.ViewHelpers do
  use Phoenix.HTML

  import Oli.Branding
  import Oli.Utils, only: [value_or: 2]

  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Branding.Brand

  def brand_logo_html(conn_or_brand, opts \\ [])

  def brand_logo_html(%Brand{name: name, logo: logo, logo_dark: logo_dark}, opts) do
    class = Keyword.get(opts, :class, "")

    ~E"""
      <img src="<%= logo %>" height="40" class="d-dark-none <%= class %>" alt="<%= name %>">
      <img src="<%= value_or(logo_dark, logo) %>" height="40" class="d-light-none <%= class %>"  alt="<%= name %>">
    """
  end

  def brand_logo_html(conn, opts) do
    class = Keyword.get(opts, :class, "")
    section = conn.assigns[:section]

    ~E"""
      <img src="<%= brand_logo_url(section) %>" height="40" class="d-dark-none <%= class %>" alt="<%= brand_name(section) %>">
      <img src="<%= brand_logo_url_dark(section) %>" height="40" class="d-light-none <%= class %>"  alt="<%= brand_name(section) %>">
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
    is_section_instructor?(section_slug, user) || is_admin?(section_slug, user)
  end

  def is_section_instructor?(section_slug, user) do
    Sections.is_enrolled?(user.id, section_slug) &&
      ContextRoles.has_role?(
        user,
        section_slug,
        ContextRoles.get_role(:context_instructor)
      )
  end

  def is_admin?(section_slug, user) do
    PlatformRoles.has_roles?(
      user,
      [
        PlatformRoles.get_role(:system_administrator),
        PlatformRoles.get_role(:institution_administrator)
      ],
      :any
    ) ||
      ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_administrator))
  end

  def maybe_section_slug(conn) do
    case conn.assigns[:section] do
      %Section{slug: slug} ->
        slug

      _ ->
        ""
    end
  end
end
