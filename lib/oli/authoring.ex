defmodule Oli.Authoring do
  # Authoring actions / data structures that are consumed by non-authoring contexts go here
  # Eg ways of accessing projects for use in Publishing or Delivery contexts
  alias Oli.Repo
  alias Oli.Authoring.Theme

  @doc """
  Returns the list of themes.
  ## Examples
      iex> list_themes()
      [%Theme{}, ...]
  """
  def list_themes do
    Repo.all(Theme)
  end

  @doc """
  Gets a theme by id
  Raises `Ecto.NoResultsError` if the Theme does not exist.
  ## Examples
      iex> get_theme!(123)
      %Theme{}
      iex> get_theme!(456)
      ** (Ecto.NoResultsError)

  """
  def get_theme!(id), do: Repo.get!(Theme, id)

  @doc """
  Gets a single theme with the given url
  """
  def get_theme_by_url!(url) do
    Repo.get_by!(Theme, url: url)
  end

  @doc """
  Gets a single theme with the given url
  """
  def get_default_theme!() do
    Repo.get_by!(Theme, default: true)
  end
end
