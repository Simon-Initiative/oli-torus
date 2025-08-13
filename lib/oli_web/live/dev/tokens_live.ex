defmodule OliWeb.Dev.TokensLive do
  @moduledoc """
  A only dev access liveview to show all color tokens available in the design system
  """

  use OliWeb, :live_view
  alias OliWeb.Icons

  def mount(_params, _session, socket) do
    tokens = read_tokens_from_file()
    tokens_by_category = group_tokens_by_category(tokens)
    flat_tokens = flatten_tokens_structure(tokens_by_category)

    {:ok,
     assign(socket,
       tokens: flat_tokens,
       hide_header: true,
       hide_footer: true,
       ctx: %{is_liveview: true}
     )}
  end

  defp read_tokens_from_file() do
    tokens_file = Path.join([File.cwd!(), "assets", "tailwind.tokens.js"])

    case File.read(tokens_file) do
      {:ok, content} -> extract_tokens(content)
      _ -> []
    end
  end

  defp extract_tokens(content) do
    Regex.scan(~r/'([^']+)':\s*\{\s*light:\s*'([^']+)',\s*dark:\s*'([^']+)'/, content)
    |> Enum.map(fn [_, name, light, dark] ->
      %{name: name, light: light, dark: dark}
    end)
  end

  defp group_tokens_by_category(tokens) do
    grouped =
      Enum.reduce(tokens, %{}, fn %{name: name} = token, acc ->
        {category, subgroup} = get_category_and_subgroup(name)

        Map.update(acc, category, %{subgroups: %{subgroup => [token]}}, fn cat_map ->
          Map.update!(cat_map, :subgroups, fn subgroups ->
            Map.update(subgroups, subgroup, [token], &[token | &1])
          end)
        end)
      end)

    grouped
    |> Map.to_list()
    |> Enum.sort_by(fn {category, _} ->
      {category == "Specially Tokens", category}
    end)
  end

  defp get_category_and_subgroup(token_name) do
    parts = String.split(token_name, "-")

    with ["Specially", "Tokens", subgroup | _] <- parts do
      {"Specially Tokens", subgroup}
    else
      _ ->
        [main | rest] = parts

        category =
          case rest do
            ["Buttons" | _] -> "Fill/Buttons"
            ["Accent" | _] -> "Fill/Accent"
            _ -> main
          end

        {category, "Default"}
    end
  end

  defp flatten_tokens_structure(grouped_tokens) do
    Enum.flat_map(grouped_tokens, fn {category, %{subgroups: subgroups}} ->
      category_block = [%{type: :category, name: category}]

      subgroup_blocks =
        Enum.flat_map(subgroups, fn {subgroup, tokens} ->
          blocks =
            if category == "Specially Tokens", do: [%{type: :subgroup, name: subgroup}], else: []

          blocks ++ [%{type: :tokens, tokens: tokens}]
        end)

      category_block ++ subgroup_blocks
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <div class="flex flex-col items-start mb-8">
        <h1 class="text-3xl font-bold">Design System Tokens</h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          * Click a color to copy its hex code.
        </p>
      </div>

      <div class="space-y-8">
        <%= for item <- @tokens do %>
          <%= case item do %>
            <% %{type: :category, name: name} -> %>
              <h2 class="text-2xl font-semibold border-b pb-2"><%= name %></h2>
            <% %{type: :subgroup, name: name} -> %>
              <h3 class="text-lg font-semibold text-gray-700 dark:text-gray-300"><%= name %></h3>
            <% %{type: :tokens, tokens: tokens} -> %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <%= for %{name: token, light: light, dark: dark} <- tokens do %>
                  <div class="rounded-lg border p-4 space-y-3">
                    <div class="flex justify-between items-center">
                      <span class="font-medium"><%= token %></span>
                      <button
                        id={token}
                        phx-hook="CopyToClipboard"
                        data-copy-text={token}
                        class="relative ml-2 text-gray-500 hover:text-gray-900 dark:hover:text-white"
                        title="Copiar al portapapeles"
                      >
                        <Icons.clipboard />
                      </button>
                    </div>

                    <div class="flex flex-row items-center gap-2">
                      <div class="flex flex-col items-center">
                        <div
                          id={"light-#{token}"}
                          class="w-16 h-10 rounded border cursor-pointer relative"
                          style={"background-color: #{light}"}
                          phx-hook="CopyToClipboard"
                          data-copy-text={light}
                        />
                        <span class="text-xs">Light</span>
                      </div>

                      <div class="flex flex-col items-center">
                        <div
                          id={"dark-#{token}"}
                          class="w-16 h-10 rounded border cursor-pointer relative"
                          style={"background-color: #{dark}"}
                          phx-hook="CopyToClipboard"
                          data-copy-text={dark}
                        />
                        <span class="text-xs">Dark</span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
