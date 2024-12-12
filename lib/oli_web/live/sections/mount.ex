defmodule OliWeb.Sections.Mount do
  alias Oli.Accounts
  alias Oli.Accounts.{SystemRole, User, Author}
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView
  alias Oli.Delivery.Sections

  import OliWeb.ViewHelpers,
    only: [
      is_section_instructor_or_admin?: 2
    ]

  def for(section_slug, session) do
    user_id = Map.get(session, "current_user_id")
    author_id = Map.get(session, "current_author_id")

    case Sections.get_section_by_slug(section_slug) do
      nil ->
        {:error, :not_found}

      %Oli.Delivery.Sections.Section{type: :blueprint} = section ->
        case ensure_author_of(section, author_id) do
          {:error, _} -> ensure_admin(section, author_id)
          result -> result
        end

      section ->
        case {user_id, author_id} do
          {nil, author_id} ->
            ensure_admin(section, author_id)

          {user_id, nil} ->
            ensure_instructor(section, user_id)

          {user_id, author_id} ->
            # prioritize system admin over instructor
            case ensure_admin(section, author_id) do
              {:error, _} -> ensure_instructor(section, user_id)
              e -> e
            end
        end
    end
  end

  defp ensure_author_of(_, nil), do: {:error, :unauthorized}

  defp ensure_author_of(section, author_id) do
    author = Oli.Accounts.get_author!(author_id)

    case Oli.Delivery.Sections.Blueprint.is_author_of_blueprint?(section.slug, author_id) do
      true -> {:author, author, section}
      _ -> {:error, :unauthorized}
    end
  end

  defp ensure_admin(_, nil), do: {:error, :unauthorized}

  defp ensure_admin(section, author_id) do
    author = Oli.Accounts.get_author!(author_id)

    case Accounts.is_admin?(author) do
      true -> {:admin, author, section}
      _ -> {:error, :unauthorized}
    end
  end

  defp ensure_instructor(section, user_id) do
    current_user = Accounts.get_user!(user_id, preload: [:platform_roles, :author])

    if is_section_instructor_or_admin?(section.slug, current_user) do
      {:user, current_user, section}
    else
      {:error, :unauthorized}
    end
  end

  def is_lms_or_system_admin?(user, section) do
    admin_role_id = SystemRole.role_id().system_admin

    case user do
      %Author{system_role_id: ^admin_role_id} -> true
      %User{} = user -> OliWeb.ViewHelpers.is_admin?(section.slug, user)
      _ -> false
    end
  end

  def handle_error(socket, {:error, exact_error}) do
    {:ok, LiveView.redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, exact_error))}
  end
end
