defmodule OliWeb.SecureSocket do
  @moduledoc "Versioned socket capabilities backed by one current session row."
  alias Oli.Accounts
  @salt "assessment session socket v2"

  @doc "Signs a reference to the authenticated session, never its bearer token."
  def sign(endpoint, %{token_id: id}),
    do: Phoenix.Token.sign(endpoint, @salt, %{v: 2, session_id: id})

  @doc "Verifies the signature and reloads the exact unexpired session."
  def verify(endpoint, token) do
    with {:ok, %{v: 2, session_id: id}} <-
           Phoenix.Token.verify(endpoint, @salt, token, max_age: 1_209_600) do
      Accounts.get_user_session_by_id(id)
    end
  end

  @doc "Revalidates a socket before subscriptions, delayed reads or outbound data."
  def unrestricted?(%{assigns: %{user_session: %{token_id: id}}}) do
    case Accounts.get_user_session_by_id(id) do
      {:ok, %{scope: nil}} -> true
      _ -> false
    end
  end

  def unrestricted?(%{assigns: assigns}), do: not Map.has_key?(assigns, :user_session)

  @doc "Checks channel ownership and current resource policy, including legacy ordinary credentials."
  def channel_allowed?(socket, topic) do
    with true <- unrestricted?(socket) do
      case topic do
        "user_global_state:" <> user_id ->
          owns?(socket, user_id)

        "user_section_state:" <> suffix ->
          case String.split(suffix, ":") do
            [section_slug, user_id] -> owns?(socket, user_id) and enrolled?(socket, section_slug)
            _ -> false
          end

        "directed_discussion:" <> suffix ->
          case String.split(suffix, ":") do
            [section_slug, resource_id] ->
              with {resource_id, ""} <- Integer.parse(resource_id),
                   section when not is_nil(section) <-
                     Oli.Delivery.Sections.get_section_by(slug: section_slug),
                   %{secure_delivery: false} <-
                     Oli.Repo.get_by(Oli.Delivery.Sections.SectionResource,
                       section_id: section.id,
                       resource_id: resource_id
                     ) do
                enrolled?(socket, section_slug) and
                  not Oli.Delivery.SecureAssessments.protected_models?(section_slug, [resource_id])
              else
                _ -> false
              end

            _ ->
              false
          end

        "clickhouse_chunk_logs:" <> _ ->
          true

        _ ->
          false
      end
    end
  end

  defp user(%{assigns: %{user_session: %{user: user}}}), do: user
  defp user(%{assigns: %{user: sub}}) when is_binary(sub), do: Accounts.get_user_by(sub: sub)
  defp user(_), do: nil

  defp owns?(socket, id) do
    case user(socket) do
      %{id: user_id} -> Integer.to_string(user_id) == id
      _ -> false
    end
  end

  defp enrolled?(socket, section_slug) do
    case user(socket) do
      %{id: id} -> Oli.Delivery.Sections.is_enrolled?(id, section_slug)
      _ -> false
    end
  end
end
