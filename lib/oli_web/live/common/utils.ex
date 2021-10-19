defmodule OliWeb.Common.Utils do
  alias Oli.Accounts.{User, Author}

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

  defp has_value(v) do
    !is_nil(v) and v != ""
  end
end
