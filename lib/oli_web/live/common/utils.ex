defmodule OliWeb.Common.Utils do
  import OliWeb.Common.FormatDateTime

  alias Oli.Accounts.{User, Author}
  alias OliWeb.Common.SessionContext

  def name(%User{} = user) do
    name(user.name, user.given_name, user.family_name)
  end

  def name(%Author{} = author) do
    name(author.name, author.given_name, author.family_name)
  end

  def name(name, given_name, family_name) do
    case {has_value(name), has_value(given_name), has_value(family_name)} do
      {_, true, true} -> "#{family_name}, #{given_name}"
      {false, false, true} -> family_name
      {true, _, _} -> name
      _ -> "Unknown"
    end
  end

  def render_date(item, attr_name, %SessionContext{} = context) do
    opts = [context: context, show_timezone: false]
    render_date_with_opts(item, attr_name, opts)
  end

  def render_date(item, attr_name, %Plug.Conn{} = conn) do
    opts = [conn: conn, show_timezone: false]
    render_date_with_opts(item, attr_name, opts)
  end

  def render_relative_date(item, attr_name, context) do
    opts = [context: context, precision: :relative]
    render_date_with_opts(item, attr_name, opts)
  end

  def render_precise_date(item, attr_name, context) do
    opts = [context: context, precision: :minutes]
    render_date_with_opts(item, attr_name, opts)
  end

  def render_date_with_opts(item, attr_name, opts), do: date(Map.get(item, attr_name), opts)

  defp has_value(v) do
    !is_nil(v) and v != ""
  end
end
