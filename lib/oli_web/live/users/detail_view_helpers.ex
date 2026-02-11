defmodule OliWeb.Users.DetailViewHelpers do
  alias Oli.Accounts.{Author, User}
  alias Oli.AssentAuth.{AuthorAssentAuth, UserAssentAuth}

  def formatted_header_name(%{family_name: family, given_name: given, name: name}) do
    family = family || ""
    given = given || ""

    case {String.trim(family), String.trim(given)} do
      {"", ""} -> name || ""
      {family, ""} -> family
      {"", given} -> given
      {family, given} -> "#{family}, #{given}"
    end
  end

  def credentials_has_google?(identities) when is_list(identities) do
    Enum.any?(identities, &(&1.provider == "google"))
  end

  def credentials_label(%Author{} = author, has_google) do
    has_password = AuthorAssentAuth.has_password?(author)

    cond do
      has_google and has_password -> "Email & Password"
      has_google -> nil
      has_password -> "Email & Password"
      true -> "None"
    end
  end

  def credentials_label(%User{} = user, has_google) do
    has_password = UserAssentAuth.has_password?(user)

    cond do
      has_google and has_password -> "Email & Password"
      has_google -> nil
      has_password -> "Email & Password"
      true -> "None"
    end
  end
end
