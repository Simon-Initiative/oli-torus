defmodule OliWeb.AuthoringView do
  use OliWeb, :view
  use Phoenix.Component

  alias Oli.Accounts
  alias Oli.Accounts.Author

  def author_role_text(author) do
    if Accounts.is_admin?(author),
      do: "Admin",
      else: "Author"
  end

  def author_role_color(author) do
    if Accounts.is_admin?(author),
      do: "admin-color",
      else: "author-color"
  end

  def author_linked_account(%Author{} = author),
    do: Accounts.get_user_by(author_id: author.id)

  def author_icon(%{assigns: %{current_author: current_author} = assigns}) do
    case current_author.picture do
      nil ->
        author_icon(%{})

      picture ->
        assigns = assign(assigns, :picture, picture)

        ~H"""
        <div class="user-icon">
          <img src={@picture} class="rounded-circle" />
        </div>
        """
    end
  end

  def author_icon(assigns) do
    ~H"""
    <div class="user-icon">
      <div class="user-img rounded-circle">
        <span class="material-icons text-secondary">account_circle</span>
      </div>
    </div>
    """
  end
end
