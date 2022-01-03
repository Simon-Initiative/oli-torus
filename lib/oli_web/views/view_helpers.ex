defmodule OliWeb.ViewHelpers do
  use Phoenix.HTML

  import Oli.Branding
  import Oli.Utils, only: [value_or: 2]

  alias Oli.Accounts
  alias Oli.Accounts.Author
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

  @doc """
  Converts a datetime to a specific timezone based on a user's session or specified timezone
  and returns a formatted string.

  This session timezone information is set and updated on the timezone api call every time a
  page is loaded.

  ## Examples
      iex> dt(datetime, conn)
      "December 31, 2021 at 11:59:59 PM"

      iex> dt(datetime, "America/New_York")
      "December 31, 2021 at 11:59:59 PM"

      iex> dt(datetime, nil)
      "January 1, 2022 at 4:59:59 AM UTC"

      iex> dt(datetime)
      "January 1, 2022 at 4:59:59 AM UTC"

      iex> dt(datetime, conn, precision: :date)
      "January 1, 2022"

      iex> dt(datetime, conn, precision: :relative)
      "8 minutes ago"
  """
  def dt(datetime, opts \\ [])

  def dt(datetime, %Plug.Conn{assigns: assigns} = conn) do
    case Map.get(assigns, :current_author) do
      %Author{} = author ->
        dt(datetime, conn: conn, author: author)

      _ ->
        dt(datetime, conn: conn)
    end
  end

  def dt(datetime, opts) do
    maybe_conn_or_local_tz = Keyword.get(opts, :conn, Keyword.get(opts, :local_tz))

    datetime
    |> maybe_localized_datetime(maybe_conn_or_local_tz)
    |> format_datetime(opts)
  end

  def dt(datetime, %Plug.Conn{assigns: assigns} = conn, opts) do
    case Map.get(assigns, :current_author) do
      %Author{} = author ->
        dt(datetime, Keyword.merge(opts, conn: conn, author: author))

      _ ->
        dt(datetime, Keyword.merge(opts, conn: conn))
    end
  end

  @doc """
  Converts a datetime to a specific timezone based on a user's session. This
  session timezone information is set and updated on the timezone api call every
  time a page is loaded.
  """
  def maybe_localized_datetime(%DateTime{} = datetime, %Plug.Conn{} = conn),
    do: maybe_localized_datetime(datetime, Plug.Conn.get_session(conn, "local_tz"))

  def maybe_localized_datetime(%DateTime{} = datetime, nil), do: datetime

  def maybe_localized_datetime(%DateTime{} = datetime, timezone) when is_binary(timezone) do
    # ensure timezone is a valid
    if Timex.Timezone.exists?(timezone) do
      {:localized, Timex.Timezone.convert(datetime, Timex.Timezone.get(timezone, Timex.now()))}
    else
      datetime
    end
  end

  @doc """
  Formats a datetime by converting it to a string. If the timezone attached is UTC, then
  it is assumed this datetime has not been localized and the timezone is included.

  Precision of the datetime can be set to :date, :minutes, or :minutes (default)

  ## Examples
      iex> dt(datetime)
      "December 31, 2021 at 11:59:59 PM UTC"

      iex> dt({:localized, datetime_utc})
      "December 31, 2021 at 11:59:59 PM"

      iex> dt({:localized, datetime}, precision: :date)
      "December 31, 2021"

      iex> dt({:localized, datetime}, precision: :minutes)
      "December 31, 2021 at 11:59 PM"

      iex> dt({:localized, datetime}, precision: :relative)
      "8 minutes ago"

      iex> dt(datetime, :relative)
      "5 hours ago"

      # author has preference show_relative_dates set to true
      iex> dt(datetime, author: author)
      "8 minutes ago"
  """
  def format_datetime(maybe_localized_datetime, opts \\ [])

  def format_datetime(nil, _opts), do: ""

  def format_datetime({:localized, %DateTime{} = datetime}, opts) do
    # default to showing no timezone if the datetime has been localized
    format_datetime(datetime, Keyword.put_new(opts, :show_timezone, false))
  end

  def format_datetime(%DateTime{} = datetime, opts) do
    author = Keyword.get(opts, :author)

    precision =
      Keyword.get(opts, :precision)
      |> value_or(author_format_preference(author))
      |> value_or(:minutes)

    show_timezone = Keyword.get(opts, :show_timezone, true)

    # show the timezone if the datetime hasnt been converted to a local timezone
    maybe_timezone =
      if show_timezone do
        " {Zabbr}"
      else
        ""
      end

    case precision do
      :date ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY}#{maybe_timezone}")

      :minutes ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY} at {h12}:{m} {AM}#{maybe_timezone}")

      :seconds ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY} at {h12}:{m}:{s} {AM}#{maybe_timezone}")

      :relative ->
        Timex.format!(datetime, "{relative}", :relative)
    end
  end

  defp author_format_preference(nil), do: nil

  defp author_format_preference(author) do
    if Accounts.get_author_preference(author, :show_relative_dates) do
      :relative
    else
      nil
    end
  end
end
