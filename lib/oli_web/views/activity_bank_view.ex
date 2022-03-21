defmodule OliWeb.ActivityBankView do
  use OliWeb, :view

  alias OliWeb.Router.Helpers, as: Routes

  @doc """

  Will Jason.encode! and URI.encode the input to return a version suitable for use to output
  within a <script> tag of a template.

  Within a template, when we have user-supplied data, it lets us more safely do a

  <script>
   const encodedParams = "<%= json_escape(@context) %>";
   const params = JSON.parse(decodeURIComponent(encodedParams));
  </script>

  instead of an unsafe:

  <script>
   const params = <%= raw( Jason.encode!(@context) ) %>;
  </script>

  """
  def json_escape(input) do
    {:safe,
     input
     |> Jason.encode!()
     |> URI.encode(&json_char_escaped/1)}
  end

  # we're not going to encode a few characters, to make our string a little smaller and more readable
  defp json_char_escaped(c) when c in [32, ?:, ?{, ?}], do: true
  defp json_char_escaped(c), do: URI.char_unescaped?(c)

  def render_activity(activity, activity_type, section_slug) do
    tag = activity_type.authoring_element

    "<#{tag} model=\"#{activity.encoded_model}\" editmode=\"false\" projectSlug=\"#{section_slug}\"></#{tag}>"
  end

  def page_url(conn, offset) do
    %{
      section_slug: section_slug,
      revision_slug: revision_slug,
      selection_id: selection_id
    } = conn.assigns

    Routes.activity_bank_path(conn, :preview, section_slug, revision_slug, selection_id,
      offset: offset
    )
  end
end
