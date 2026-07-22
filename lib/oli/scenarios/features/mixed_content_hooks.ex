defmodule Oli.Scenarios.Features.MixedContentHooks do
  @moduledoc """
  Scenario hooks that rebuild mixed-workflow context and assert author preview
  plus published delivery content after Playwright authoring steps.
  """

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [get: 2, html_response: 2]

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Types.BuiltProject
  alias OliWeb.Router.Helpers, as: Routes

  @endpoint OliWeb.Endpoint

  @project_name "workflow_authoring_project"
  @section_name "workflow_delivery_section"
  @page_title "Mixed Workflow Page"
  @author_name "workflow_author"
  @student_name "workflow_student"

  @doc """
  Rebuilds the scenario execution state from workflow params after a Playwright step.
  """
  def bind_workflow_context(%ExecutionState{} = state) do
    author = fetch_author_from_params!(state)
    student = fetch_student_from_params!(state)
    project = fetch_project_from_params!(state)
    section = fetch_section_from_params!(state)
    revision = fetch_revision_from_params!(state, project.slug)

    built_project = %BuiltProject{
      project: project,
      rev_by_title: %{@page_title => revision}
    }

    %{
      state
      | current_author: author,
        projects: Map.put(state.projects, @project_name, built_project),
        sections: Map.put(state.sections, @section_name, section),
        users:
          state.users
          |> Map.put(@author_name, author)
          |> Map.put(@student_name, student),
        params: Map.put(state.params || %{}, "workflow_page_revision_slug", revision.slug)
    }
  end

  @doc """
  Captures the authored page revision slug into scenario params for later workflow steps.
  """
  def capture_workflow_page_revision_slug(%ExecutionState{} = state) do
    revision = fetch_page_revision!(state)
    %{state | params: Map.put(state.params || %{}, "workflow_page_revision_slug", revision.slug)}
  end

  @doc """
  Asserts that the author preview renders the expected code block content.
  """
  def assert_author_preview_codeblock(%ExecutionState{} = state) do
    html = author_preview_html(state)
    text = html_text(html)

    assert_contains(text, state.params["EXPECTED_CODEBLOCK_CAPTION"])
    assert_contains(text, state.params["EXPECTED_CODEBLOCK_CODE"])

    state
  end

  @doc """
  Asserts that the text entered for the CORE-A workflow appears in author preview.
  """
  def assert_author_preview_core_text_editing(%ExecutionState{} = state) do
    state
    |> author_preview_html()
    |> html_text()
    |> assert_contains(required_param!(state, "EXPECTED_TYPED_TEXT"))

    state
  end

  @doc """
  Asserts that the published delivery revision contains the expected code block content.
  """
  def assert_student_delivery_codeblock(%ExecutionState{} = state) do
    content = delivered_revision_content(state)

    assert nested_contains?(content, state.params["EXPECTED_CODEBLOCK_CAPTION"])
    assert nested_contains?(content, state.params["EXPECTED_CODEBLOCK_CODE"])

    state
  end

  @doc """
  Asserts that the text entered for the CORE-A workflow persists to published delivery content.
  """
  def assert_student_delivery_core_text_editing(%ExecutionState{} = state) do
    assert nested_contains?(
             delivered_revision_content(state),
             required_param!(state, "EXPECTED_TYPED_TEXT")
           )

    state
  end

  @doc """
  Asserts that inline marks plus block format/direction render in author preview.
  """
  def assert_author_preview_inline_formatting(%ExecutionState{} = state) do
    html = author_preview_html(state)

    expected_inline_formatting!(state)
    |> Enum.each(fn expected ->
      assert_preview_formatting!(html, expected)
    end)

    state
  end

  @doc """
  Asserts that inline marks plus block format/direction persist to delivery.
  """
  def assert_student_delivery_inline_formatting(%ExecutionState{} = state) do
    content = delivered_revision_content(state)

    expected_inline_formatting!(state)
    |> Enum.each(fn expected ->
      assert_delivery_formatting!(content, expected)
    end)

    state
  end

  @doc """
  Asserts that an inline link renders with the expected target in author preview.
  """
  def assert_author_preview_inline_link(%ExecutionState{} = state) do
    html = author_preview_html(state)
    link_text = required_param!(state, "EXPECTED_LINK_TEXT")
    link_type = required_param!(state, "EXPECTED_LINK_TYPE")

    case link_type do
      "url" ->
        href = required_param!(state, "EXPECTED_LINK_HREF")

        assert html_has_text?(html, ~s|a[href="#{href}"]|, link_text),
               "Expected external author-preview link #{inspect(href)}"

      "page" ->
        href = required_param!(state, "EXPECTED_LINK_HREF")
        project_slug = fetch_project!(state).project.slug

        assert html_has_link_to_target?(html, href, project_slug, link_text),
               "Expected internal author-preview link #{inspect(link_text)}"
    end

    state
  end

  @doc """
  Asserts that an inline link preserves its type, target, and text in delivery content.
  """
  def assert_student_delivery_inline_link(%ExecutionState{} = state) do
    content = delivered_revision_content(state)
    link_text = required_param!(state, "EXPECTED_LINK_TEXT")
    link_type = required_param!(state, "EXPECTED_LINK_TYPE")

    expected_link? =
      case link_type do
        "url" ->
          href = required_param!(state, "EXPECTED_LINK_HREF")
          &(&1["type"] == "a" and &1["href"] == href and nested_contains?(&1, link_text))

        "page" ->
          href = required_param!(state, "EXPECTED_LINK_HREF")

          &(&1["type"] == "a" and &1["linkType"] == "page" and &1["href"] == href and
              nested_contains?(&1, link_text))
      end

    assert nested_map?(content, expected_link?),
           "Expected published #{link_type} link #{inspect(link_text)}"

    state
  end

  @doc """
  Asserts that inline foreign text renders in author preview.
  """
  def assert_author_preview_inline_foreign(%ExecutionState{} = state),
    do: assert_preview_text(state, "EXPECTED_TEXT")

  @doc """
  Asserts that an inline popup trigger is passed to the author-preview React renderer.
  """
  def assert_author_preview_inline_popup(%ExecutionState{} = state) do
    trigger = required_param!(state, "EXPECTED_TRIGGER")

    assert html_has_attribute_text?(
             author_preview_html(state),
             ~s|[data-react-class="Components.DeliveryElementRenderer"]|,
             "data-react-props",
             trigger
           ),
           "Expected author-preview popup renderer to receive #{inspect(trigger)}"

    state
  end

  @doc """
  Asserts that an inline callout renders in author preview.
  """
  def assert_author_preview_inline_callout(%ExecutionState{} = state),
    do: assert_preview_text(state, "EXPECTED_TEXT")

  @doc """
  Asserts that inline foreign text persists in delivery content.
  """
  def assert_student_delivery_inline_foreign(%ExecutionState{} = state),
    do: assert_delivery_element_text(state, "foreign", "EXPECTED_TEXT")

  @doc """
  Asserts that inline popup content persists in delivery content.
  """
  def assert_student_delivery_inline_popup(%ExecutionState{} = state),
    do: assert_delivery_element_text(state, "popup", "EXPECTED_CONTENT")

  @doc """
  Asserts that an inline callout persists in delivery content.
  """
  def assert_student_delivery_inline_callout(%ExecutionState{} = state),
    do: assert_delivery_element_text(state, "callout_inline", "EXPECTED_TEXT")

  @doc """
  Asserts that list style and nesting render in author preview.
  """
  def assert_author_preview_list_formatting(%ExecutionState{} = state) do
    html = author_preview_html(state)
    styled_item = required_param!(state, "EXPECTED_STYLED_LIST_ITEM")
    indented_item = required_param!(state, "EXPECTED_INDENTED_LIST_ITEM")

    assert html_has_text?(html, "ul", styled_item), "Expected styled item in author-preview list"

    assert html_has_text?(html, "ul ul", indented_item),
           "Expected indented item in nested author-preview list"

    state
  end

  @doc """
  Asserts that list style and nesting persist in delivery content.
  """
  def assert_student_delivery_list_formatting(%ExecutionState{} = state) do
    content = delivered_revision_content(state)
    styled_item = required_param!(state, "EXPECTED_STYLED_LIST_ITEM")
    indented_item = required_param!(state, "EXPECTED_INDENTED_LIST_ITEM")

    assert nested_map?(
             content,
             &(&1["type"] == "ul" and &1["style"] == "circle" and
                 nested_contains?(&1, styled_item))
           ),
           "Expected published circle-style list item"

    assert nested_map?(content, fn node ->
             node["type"] == "ul" and
               nested_map?(
                 node["children"] || [],
                 &(&1["type"] == "ul" and nested_contains?(&1, indented_item))
               )
           end),
           "Expected published nested list item"

    state
  end

  @doc """
  Asserts that table structure and cell formatting render in author preview.
  """
  def assert_author_preview_table_structure(%ExecutionState{} = state) do
    html = author_preview_html(state)
    header_text = required_param!(state, "EXPECTED_HEADER_TEXT")
    merged_text = required_param!(state, "EXPECTED_MERGED_TEXT")
    aligned_text = required_param!(state, "EXPECTED_ALIGNED_TEXT")

    assert html_has_text?(html, "table th", header_text), "Expected author-preview table header"

    assert html_has_text?(html, "table [colspan=\"2\"]", merged_text),
           "Expected author-preview merged table cells"

    assert html_has_text?(html, "table .text-center", aligned_text),
           "Expected author-preview centered table cell"

    assert html |> Floki.parse_document!() |> Floki.find("table tr") |> length() >= 3,
           "Expected author-preview table to contain the added row"

    assert html
           |> Floki.parse_document!()
           |> Floki.find("table tr:first-child td, table tr:first-child th")
           |> length() >= 3,
           "Expected author-preview table to contain the added column"

    state
  end

  @doc """
  Asserts that table structure and cell formatting persist in delivery content.
  """
  def assert_student_delivery_table_structure(%ExecutionState{} = state) do
    content = delivered_revision_content(state)
    header_text = required_param!(state, "EXPECTED_HEADER_TEXT")
    merged_text = required_param!(state, "EXPECTED_MERGED_TEXT")
    aligned_text = required_param!(state, "EXPECTED_ALIGNED_TEXT")

    assert nested_map?(content, &(&1["type"] == "table" and length(&1["children"] || []) >= 3)),
           "Expected published table to contain the added row"

    assert nested_map?(content, &(&1["type"] == "th" and nested_contains?(&1, header_text))),
           "Expected published table header"

    assert nested_map?(
             content,
             &(&1["type"] == "td" and &1["colspan"] == 2 and nested_contains?(&1, merged_text))
           ),
           "Expected published merged table cells"

    assert nested_map?(
             content,
             &(&1["type"] == "td" and &1["align"] == "center" and
                 nested_contains?(&1, aligned_text))
           ),
           "Expected published centered table cell"

    state
  end

  @doc """
  Asserts that table row and border styles render in author preview.
  """
  def assert_author_preview_table_styles(%ExecutionState{} = state) do
    html = author_preview_html(state)
    alternating_text = required_param!(state, "EXPECTED_ALTERNATING_TEXT")
    hidden_border_text = required_param!(state, "EXPECTED_HIDDEN_BORDER_TEXT")

    assert html_has_text?(html, "table.table-striped", alternating_text),
           "Expected author-preview alternating-row table"

    assert html_has_text?(html, "table.table-borderless", hidden_border_text),
           "Expected author-preview hidden-border table"

    state
  end

  @doc """
  Asserts that table row and border styles persist in delivery content.
  """
  def assert_student_delivery_table_styles(%ExecutionState{} = state) do
    content = delivered_revision_content(state)
    alternating_text = required_param!(state, "EXPECTED_ALTERNATING_TEXT")
    hidden_border_text = required_param!(state, "EXPECTED_HIDDEN_BORDER_TEXT")

    assert nested_map?(content, fn node ->
             node["type"] == "table" and node["rowstyle"] == "alternating" and
               length(node["children"] || []) == 4 and nested_contains?(node, alternating_text)
           end),
           "Expected published four-row alternating table"

    assert nested_map?(content, fn node ->
             node["type"] == "table" and node["border"] == "hidden" and
               nested_contains?(node, hidden_border_text)
           end),
           "Expected published hidden-border table"

    state
  end

  @doc """
  Asserts that image selection and settings render in author preview.
  """
  def assert_author_preview_image_workflow(%ExecutionState{} = state) do
    html = author_preview_html(state)
    image = required_param!(state, "EXPECTED_IMAGE")
    caption = required_param!(state, "EXPECTED_CAPTION")
    alt = required_param!(state, "EXPECTED_ALT")
    width = required_param!(state, "EXPECTED_WIDTH")

    assert html_has_selector?(html, ~s|img[src*="#{image}"][alt="#{alt}"]|),
           "Expected author-preview image #{inspect(image)} with alternative text"

    assert html_has_text?(html, ".figure-caption", caption)

    assert html_has_selector?(html, ~s|img[src*="#{image}"][width="#{width}"]|),
           "Expected author-preview image #{inspect(image)} with width #{inspect(width)}"

    state
  end

  @doc """
  Asserts that image selection and settings persist in delivery content.
  """
  def assert_student_delivery_image_workflow(%ExecutionState{} = state) do
    content = delivered_revision_content(state)

    assert nested_map?(
             content,
             &(&1["type"] == "img" and
                 String.contains?(&1["src"] || "", required_param!(state, "EXPECTED_IMAGE")) and
                 &1["alt"] == required_param!(state, "EXPECTED_ALT") and
                 &1["width"] == String.to_integer(required_param!(state, "EXPECTED_WIDTH")))
           ),
           "Expected published image with selected source, alternative text, and width"

    assert nested_contains?(content, required_param!(state, "EXPECTED_CAPTION"))
    state
  end

  @doc """
  Asserts that a figure title and nested content render in author preview.
  """
  def assert_author_preview_figure_workflow(%ExecutionState{} = state) do
    html = author_preview_html(state)
    assert html_has_text?(html, ".figure figcaption", required_param!(state, "EXPECTED_TITLE"))

    assert html_has_text?(
             html,
             ".figure .figure-content",
             required_param!(state, "EXPECTED_CONTENT")
           )

    state
  end

  @doc """
  Asserts that a figure title and nested content persist in delivery content.
  """
  def assert_student_delivery_figure_workflow(%ExecutionState{} = state) do
    content = delivered_revision_content(state)

    assert nested_map?(
             content,
             &(&1["type"] == "figure" and
                 nested_contains?(&1, required_param!(state, "EXPECTED_TITLE")) and
                 nested_contains?(&1, required_param!(state, "EXPECTED_CONTENT")))
           )

    state
  end

  @doc """
  Asserts that the author preview renders the expected callout content.
  """
  def assert_author_preview_callout(%ExecutionState{} = state) do
    html = author_preview_html(state)
    text = html_text(html)

    assert_contains(text, state.params["EXPECTED_CALLOUT_TEXT"])

    state
  end

  @doc """
  Asserts that the published delivery revision contains the expected callout content.
  """
  def assert_student_delivery_callout(%ExecutionState{} = state) do
    content = delivered_revision_content(state)

    assert nested_contains?(content, state.params["EXPECTED_CALLOUT_TEXT"])

    state
  end

  defp author_preview_html(%ExecutionState{} = state) do
    author = fetch_user!(state, @author_name)
    built_project = fetch_project!(state)
    revision = fetch_page_revision!(state)

    build_conn_as_author(author)
    |> get(Routes.resource_path(@endpoint, :preview, built_project.project.slug, revision.slug))
    |> html_response(200)
  end

  defp delivered_revision_content(%ExecutionState{} = state) do
    section = fetch_section!(state)
    revision = fetch_page_revision!(state)

    case DeliveryResolver.from_resource_id(section.slug, revision.resource_id) do
      nil ->
        raise "Delivery revision for resource #{revision.resource_id} not found in section #{section.slug}"

      delivered_revision ->
        delivered_revision.content
    end
  end

  defp fetch_project!(%ExecutionState{} = state) do
    case Map.get(state.projects, @project_name) do
      nil -> raise "Project #{@project_name} not found in scenario state"
      built_project -> built_project
    end
  end

  defp fetch_section!(%ExecutionState{} = state) do
    case Map.get(state.sections, @section_name) do
      nil -> raise "Section #{@section_name} not found in scenario state"
      section -> section
    end
  end

  defp fetch_user!(%ExecutionState{} = state, name) do
    case Map.get(state.users, name) do
      nil -> raise "User #{name} not found in scenario state"
      user -> user
    end
  end

  defp fetch_page_revision!(%ExecutionState{} = state) do
    built_project = fetch_project!(state)

    case Map.get(built_project.rev_by_title, @page_title) do
      nil -> raise "Page #{@page_title} not found in built project"
      revision -> revision
    end
  end

  defp fetch_author_from_params!(%ExecutionState{} = state) do
    email = required_param!(state, "AUTHOR_EMAIL")

    case Accounts.get_author_by_email(email) do
      %Author{} = author -> author
      _ -> raise "Author with email #{email} not found"
    end
  end

  defp fetch_student_from_params!(%ExecutionState{} = state) do
    email = required_param!(state, "STUDENT_EMAIL")

    case Repo.get_by(User, email: email) do
      %User{} = user -> user
      _ -> raise "User with email #{email} not found"
    end
  end

  defp fetch_project_from_params!(%ExecutionState{} = state) do
    slug = required_param!(state, "PROJECT_SLUG")

    case Course.get_project_by_slug(slug) do
      nil -> raise "Project with slug #{slug} not found"
      project -> project
    end
  end

  defp fetch_section_from_params!(%ExecutionState{} = state) do
    slug = required_param!(state, "SECTION_SLUG")

    case Sections.get_section_by(slug: slug) do
      nil -> raise "Section with slug #{slug} not found"
      section -> section
    end
  end

  defp fetch_revision_from_params!(%ExecutionState{} = state, project_slug) do
    revision_slug = required_param!(state, "PAGE_REVISION_SLUG")

    case AuthoringResolver.from_revision_slug(project_slug, revision_slug) do
      nil -> raise "Revision with slug #{revision_slug} not found for project #{project_slug}"
      revision -> revision
    end
  end

  defp assert_contains(html, expected) when is_binary(expected) and expected != "" do
    assert html =~ expected
  end

  defp assert_contains(_html, expected) do
    raise "Expected non-empty string assertion value, got: #{inspect(expected)}"
  end

  defp required_param!(%ExecutionState{} = state, key) do
    case Map.get(state.params || %{}, key) do
      value when is_binary(value) and value != "" ->
        value

      value ->
        raise "Expected scenario param #{key} to be a non-empty string, got: #{inspect(value)}"
    end
  end

  defp html_text(html) do
    html
    |> Floki.parse_document!()
    |> Floki.text(sep: " ")
  end

  defp build_conn_as_author(author) do
    token = Accounts.generate_author_session_token(author)

    Phoenix.ConnTest.build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:author_token, token)
    |> Plug.Conn.put_session(:current_author_id, author.id)
  end

  defp expected_inline_formatting!(state) do
    state
    |> required_param!("EXPECTED_INLINE_FORMATTING")
    |> Jason.decode!()
  end

  defp assert_preview_formatting!(html, %{"text" => text, "mark" => mark}) do
    selector =
      case mark do
        "strong" -> "strong"
        "em" -> "em"
        "code" -> "code"
        "underline" -> ~s|span[style*="underline"]|
        "strikethrough" -> ~s|span[style*="line-through"]|
        "sub" -> "sub"
        "sup" -> "sup"
        "term" -> ".term"
      end

    assert html_has_text?(html, selector, text),
           "Expected author preview #{selector} to contain #{inspect(text)}"
  end

  defp assert_preview_formatting!(html, %{"text" => text, "element" => element}) do
    selector = if element == "heading", do: "h1, h2, h3, h4, h5, h6", else: element

    assert html_has_text?(html, selector, text),
           "Expected author preview #{element} to contain #{inspect(text)}"
  end

  defp assert_preview_formatting!(html, %{"text" => text, "direction" => "rtl"}) do
    assert html_has_text?(html, "[dir=rtl]", text),
           "Expected right-to-left author preview content #{inspect(text)}"
  end

  defp assert_delivery_formatting!(content, %{"text" => text, "mark" => mark}) do
    assert nested_map?(content, &(&1["text"] == text and &1[mark] == true)),
           "Expected delivery content #{inspect(text)} with #{mark} mark"
  end

  defp assert_delivery_formatting!(content, %{"text" => text, "element" => element}) do
    matches_element? = fn node ->
      node["type"] == element or
        (element == "heading" and is_binary(node["type"]) and
           String.match?(node["type"], ~r/^h[1-6]$/))
    end

    assert nested_map?(content, &(matches_element?.(&1) and nested_contains?(&1, text))),
           "Expected delivery #{element} containing #{inspect(text)}"
  end

  defp assert_delivery_formatting!(content, %{"text" => text, "direction" => "rtl"}) do
    assert nested_map?(content, &(&1["textDirection"] == "rtl" and nested_contains?(&1, text))),
           "Expected right-to-left delivery content #{inspect(text)}"
  end

  defp html_has_text?(html, selector, text) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector)
    |> Floki.text(sep: " ")
    |> String.contains?(text)
  end

  defp html_has_selector?(html, selector) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector)
    |> Enum.any?()
  end

  defp html_has_attribute_text?(html, selector, attribute, text) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector)
    |> Enum.any?(fn element ->
      element
      |> Floki.attribute(attribute)
      |> Enum.any?(&String.contains?(&1, text))
    end)
  end

  defp assert_preview_text(state, key) do
    assert_contains(html_text(author_preview_html(state)), required_param!(state, key))
    state
  end

  defp assert_delivery_element_text(state, type, key) do
    content = delivered_revision_content(state)
    text = required_param!(state, key)

    assert nested_map?(content, &(&1["type"] == type and nested_contains?(&1, text))),
           "Expected published #{type} element containing #{inspect(text)}"

    state
  end

  defp html_has_link_to_target?(html, target_href, project_slug, text) do
    expected_path = author_preview_link_path(target_href, project_slug)

    html
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.any?(fn anchor ->
      href = Floki.attribute(anchor, "href") |> List.first() || ""
      URI.parse(href).path == expected_path and Floki.text(anchor) =~ text
    end)
  end

  defp author_preview_link_path("/course/link/" <> revision_slug, project_slug)
       when revision_slug != "",
       do: "/authoring/project/#{project_slug}/preview/#{revision_slug}"

  defp author_preview_link_path(target_href, _project_slug) do
    raise "Expected internal course link, got: #{inspect(target_href)}"
  end

  defp nested_map?(value, predicate) when is_map(value) do
    predicate.(value) or Enum.any?(Map.values(value), &nested_map?(&1, predicate))
  end

  defp nested_map?(value, predicate) when is_list(value),
    do: Enum.any?(value, &nested_map?(&1, predicate))

  defp nested_map?(_, _predicate), do: false

  defp nested_contains?(value, expected) when is_binary(expected) and expected != "" do
    case value do
      text when is_binary(text) ->
        String.contains?(text, expected)

      ^expected ->
        true

      list when is_list(list) ->
        Enum.any?(list, &nested_contains?(&1, expected))

      map when is_map(map) ->
        map
        |> Map.values()
        |> Enum.any?(&nested_contains?(&1, expected))

      _ ->
        false
    end
  end

  defp nested_contains?(_value, _expected), do: false
end
