defmodule Oli.Delivery.Audience do
  @moduledoc """
  Audience mode conditionally renders content depending on the audience
  """
  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Sections

  @type role() :: :instructor | :student

  @doc """
  Returns true if a given content model is intended for a given audience

  Parameters:
  1. Content model "audience" property, can be nil
  2. User
  3. Section slug
  4. Boolean indicating whether the current context is in review mode
  """
  @spec is_intended_audience?(String.t() | nil, User.t() | nil, String.t(), boolean()) ::
          boolean()

  # user is nil, this is being called from preview so always show content
  def is_intended_audience?(_audience, nil, _section_slug, _review_mode), do: true

  def is_intended_audience?(audience, user, section_slug, review_mode) do
    role = audience_role(user, section_slug)

    is_intended_audience?(audience, role, review_mode)
  end

  def audience_role(%User{} = user, section_slug) do
    if Sections.is_instructor?(user, section_slug) do
      :instructor
    else
      :student
    end
  end

  def audience_role(%Author{} = author, _section_slug) do
    if Accounts.is_admin?(author) do
      :instructor
    else
      :student
    end
  end

  def filter_for_role(_role, %{"advancedDelivery" => true} = content) do
    content
  end

  def filter_for_role(role, content) do
    %{"model" => filter_for_role_inner(role, content["model"])}
  end

  defp filter_for_role_inner(role, content) when is_list(content) do
    content
    |> Enum.filter(fn element -> audience_matches?(role, element) end)
    |> Enum.map(fn element -> filter_for_role_inner(role, element) end)
  end

  defp filter_for_role_inner(role, content) when is_map(content) do
    case Map.has_key?(content, "children") do
      true ->
        Map.put(content, "children", filter_for_role_inner(role, content["children"]))

      false ->
        content
    end
  end

  defp audience_matches?(role, element) do
    case Map.get(element, "audience", "always") do
      "always" -> true
      "instructor" -> role == :instructor
      # Here we allow feedback nodes to pass the filter, as these nodes must be filtered out during rendering
      "feedback" -> true
      _never -> false
    end
  end

  @spec is_intended_audience?(String.t() | nil, role(), boolean()) :: boolean()

  # show the content if no audience_mode is set
  defp is_intended_audience?(nil, _role, _review_mode), do: true

  # show the content if audience_mode is always
  defp is_intended_audience?("always", _role, _review_mode), do: true

  # show the content if audience_mode is instructor and the delivery role is instructor
  defp is_intended_audience?("instructor", :instructor, _), do: true

  # show the content if audience_mode is feedback and review_mode is true
  defp is_intended_audience?("feedback", _, true), do: true

  # for all other cases, do not show the content
  defp is_intended_audience?(_audience, _role, _review_mode), do: false
end
