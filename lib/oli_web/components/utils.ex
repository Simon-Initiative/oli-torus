defmodule OliWeb.Components.Utils do
  use OliWeb, :verified_routes
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias OliWeb.Common.SessionContext
  alias Oli.Accounts.{User, Author}
  alias Oli.Delivery.Sections.Section

  def socket_or_conn(%{socket: socket} = _assigns), do: socket
  def socket_or_conn(%{conn: conn} = _assigns), do: conn

  @doc """
  A Phoenix JS utility for toggling a class and having it survive DOM patching.
  https://elixirforum.com/t/toggle-classes-with-phoenix-liveview-js/45608/5
  """
  def toggle_class(js = %{}, class, to: target) do
    js
    |> JS.remove_class(
      class,
      to: "#{target}.#{class}"
    )
    |> JS.add_class(
      class,
      to: "#{target}:not(.#{class})"
    )
  end

  @doc """
  Returns the full username of a user or author
  """
  def username(ctx) do
    case ctx do
      %SessionContext{user: %User{guest: true}} ->
        "Guest"

      %SessionContext{user: %User{name: name}} ->
        name

      %SessionContext{author: %Author{name: name}} ->
        name

      _ ->
        ""
    end
  end

  @doc """
  Returns true if the section is open and free
  """
  def is_open_and_free_section?(section) do
    case section do
      %Section{open_and_free: open_and_free} ->
        open_and_free

      _ ->
        false
    end
  end

  @doc """
  Returns true if a user is signed in as an independent learner
  """
  def is_independent_learner?(user) do
    case user do
      %User{independent_learner: true} ->
        true

      _ ->
        false
    end
  end

  attr :timezone, :string, required: true

  def timezone_info(assigns) do
    ~H"""
    <div id="timezone_info" class="flex items-center gap-2 text-[#757682] dark:text-[#bab8bf] mb-1">
      <div class="w-5 h-5 flex items-center justify-center">
        <OliWeb.Icons.timezone_world />
      </div>
      <span class="text-sm font-medium leading-4">
        <%= @timezone %>
      </span>
    </div>
    """
  end

  @doc """
  Given a list of instructors, returns a comma-separated string of their names

  ## Examples

      iex> list_instructors([%{name: "John Doe"}, %{name: "Jane Smith"}])
      "John Doe, Jane Smith"
  """
  @spec list_instructors(list(map())) :: String.t()
  def list_instructors(instructors) do
    instructors
    |> Enum.map(& &1.name)
    |> Enum.join(", ")
  end
end
