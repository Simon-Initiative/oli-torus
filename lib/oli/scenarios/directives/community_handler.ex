defmodule Oli.Scenarios.Directives.CommunityHandler do
  alias Oli.Groups
  alias Oli.Scenarios.DirectiveTypes.CommunityDirective

  def handle(
        %CommunityDirective{
          name: name,
          institution: institution_name,
          users: users,
          products: products
        },
        state
      ) do
    with :ok <- validate_association_count(users, products),
         {:ok, community} <- Groups.create_community(%{name: name}),
         {:ok, institution} <-
           fetch(state.institutions, institution_name || "default", "institution") do
      {:ok, _} =
        Groups.create_community_institution(%{
          community_id: community.id,
          institution_id: institution.id
        })

      Enum.each(users, fn user_name ->
        {:ok, user} = fetch(state.users, user_name, "user")

        {:ok, _} =
          Groups.create_community_account(%{community_id: community.id, user_id: user.id})
      end)

      Enum.each(products, fn product_name ->
        {:ok, product} = fetch(state.products, product_name, "product")

        {:ok, _} =
          Groups.create_community_visibility(%{
            community_id: community.id,
            section_id: product.id
          })
      end)

      {:ok, %{state | communities: Map.put(state.communities, name, community)}}
    end
  rescue
    e -> {:error, "Failed to create community '#{name}': #{Exception.message(e)}"}
  end

  defp fetch(map, name, type) do
    case Map.fetch(map, name) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "Unknown #{type} '#{name}'"}
    end
  end

  defp validate_association_count(users, products)
       when length(users) <= 25 and length(products) <= 25,
       do: :ok

  defp validate_association_count(_, _),
    do: {:error, "Community directives support at most 25 users and 25 products"}
end
