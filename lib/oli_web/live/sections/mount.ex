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

  def for(section_slug, socket) do
    current_author = socket.assigns[:current_author]
    current_user = socket.assigns[:current_user]

    case Sections.get_section_by_slug(section_slug) do
      nil ->
        {:error, :not_found}

      %Oli.Delivery.Sections.Section{type: :blueprint} = section ->
        case ensure_author_of(section, current_author) do
          {:error, _} -> ensure_admin(section, current_author)
          result -> result
        end

      section ->
        case {current_user, current_author} do
          {nil, author} ->
            ensure_admin(section, author)

          {user, nil} ->
            ensure_instructor(section, user)

          {user, author} ->
            # prioritize system admin over instructor
            case ensure_admin(section, author) do
              {:error, _} -> ensure_instructor(section, user)
              e -> e
            end
        end
    end
  end

  defp ensure_author_of(_, nil), do: {:error, :unauthorized}

  defp ensure_author_of(section, author) do
    case Oli.Delivery.Sections.Blueprint.is_author_of_blueprint?(section.slug, author.id) do
      true -> {:author, author, section}
      _ -> {:error, :unauthorized}
    end
  end

  defp ensure_admin(_, nil), do: {:error, :unauthorized}

  defp ensure_admin(section, author) do
    case Accounts.is_admin?(author) do
      true -> {:admin, author, section}
      _ -> {:error, :unauthorized}
    end
  end

  defp ensure_instructor(section, user) do
    if is_section_instructor_or_admin?(section.slug, user) do
      {:user, user, section}
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
