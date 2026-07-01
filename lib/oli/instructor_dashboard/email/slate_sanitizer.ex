defmodule Oli.InstructorDashboard.Email.SlateSanitizer do
  @moduledoc """
  Allowlists an instructor email body (Slate JSON) to the subset the email composer
  supports: paragraphs, text nodes (with their inline marks), and links whose href
  passes `LinkValidator.valid_internal_path?/1` (a `/course/link/:slug` or any real
  internal router route — the same contract as the send-time validator).

  Everything else — images, iframes, unknown/custom node types, off-allowlist links —
  is dropped. This defends the `update_body_slate` trust boundary: the editor UI is
  text/link-only, but a tampered client can push arbitrary Slate, which the shared
  content renderer (`Oli.Rendering.Content.Html`) would otherwise emit — including the
  raw, unescaped `element["type"]` via its unsupported-node error writer (a stored-HTML
  injection vector in the sent email). Text content is escaped by the renderer and marks
  are already allowlisted there, so text nodes are kept as-is.
  """

  alias Oli.InstructorDashboard.Email.LinkValidator

  @spec sanitize(any()) :: [map()]
  def sanitize(slate) when is_list(slate), do: Enum.flat_map(slate, &block/1)
  def sanitize(_), do: []

  # Only paragraphs survive as block-level nodes; their children are sanitized inline.
  defp block(%{"type" => "p", "children" => children}) when is_list(children),
    do: [%{"type" => "p", "children" => inline(children)}]

  defp block(_), do: []

  defp inline(children) when is_list(children), do: Enum.flat_map(children, &inline_node/1)
  defp inline(_), do: []

  # Text node: kept as-is (renderer escapes content and ignores unknown marks).
  defp inline_node(%{"text" => text} = node) when is_binary(text), do: [node]

  # Internal link: kept only when the href passes the validator; rebuilt from scratch so any
  # extra client-supplied attributes are dropped. An invalid link is unwrapped to its text.
  defp inline_node(%{"type" => "a", "href" => href, "children" => children})
       when is_binary(href) and is_list(children) do
    if LinkValidator.valid_internal_path?(href),
      do: [%{"type" => "a", "href" => href, "children" => inline(children)}],
      else: inline(children)
  end

  defp inline_node(_), do: []
end
