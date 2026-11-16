defmodule Oli.Utils.BasicPageSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}

  @factory_examples "test/support/fixtures/basic_page_elements.json"
                    |> File.read!()
                    |> Jason.decode!()

  setup_all do
    %{schema: SchemaResolver.resolve("page-content-basic.schema.json")}
  end

  defp text(value \\ ""), do: %{"text" => value}
  defp element(type, children \\ [%{"text" => ""}]), do: %{"type" => type, "children" => children}

  defp page(element),
    do: %{"version" => "0.1.0", "model" => [%{"type" => "content", "children" => [element]}]}

  for {name, element} <- @factory_examples do
    test "accepts editor factory #{name}", %{schema: schema} do
      assert :ok = JSONValidation.validate(schema, page(unquote(Macro.escape(element))))
    end
  end

  test "covers headings, legacy math, populated media and command toggle states", %{
    schema: schema
  } do
    examples =
      Enum.map(1..6, &element("h#{&1}")) ++
        [
          element("math", [element("math_line", [text("x + y")])]),
          Map.merge(element("video"), %{
            "src" => [%{"url" => "video.mp4", "contenttype" => "video/mp4"}],
            "captions" => [%{"language_code" => "en", "label" => "English", "src" => "en.vtt"}]
          }),
          Map.merge(element("iframe"), %{
            "targetId" => "frame",
            "listen" => true,
            "src" => "https://example.com"
          }),
          element("p", [
            Map.merge(element("command_button"), %{
              "target" => "frame",
              "message" => "go",
              "style" => "link",
              "toggleStates" => [%{"title" => "Next", "message" => "next"}]
            })
          ])
        ]

    for element <- examples, do: assert(:ok == JSONValidation.validate(schema, page(element)))
  end

  test "preserves supported legacy representations", %{schema: schema} do
    for element <- [
          %{"type" => "code", "language" => "Text", "children" => [element("code_line")]},
          %{"type" => "code", "code" => "hello", "language" => "Text"},
          %{"type" => "img", "caption" => "Legacy caption", "width" => "100%"},
          element("ul", [text("legacy list item")]),
          element("li", [text("legacy inline item")]),
          %{"type" => "dl", "items" => []},
          %{"type" => "dialog"},
          Map.put(element("p"), "id", 123),
          element("p", [%{"text" => "legacy marks", "strong" => true, "em" => false}])
        ] do
      assert :ok = JSONValidation.validate(schema, page(element))
    end
  end

  test "validates nesting recursively", %{schema: schema} do
    for element <- [
          element("ul", [
            element("li", [element("p"), element("ul", [element("li", [element("p")])])])
          ]),
          element("callout", [
            element("ul", [element("li", [element("p")])]),
            element("figure", []) |> Map.put("title", [])
          ]),
          element("table", [
            element("tr", [
              element("td", [
                element("p"),
                %{"type" => "formula_inline", "subtype" => "latex", "src" => "x"}
              ])
            ])
          ]),
          %{
            "type" => "img",
            "caption" => [
              element("p", [
                %{"type" => "a", "href" => "https://example.com", "children" => [text("caption")]}
              ])
            ]
          }
        ] do
      assert :ok = JSONValidation.validate(schema, page(element))
    end

    for element <- [
          element("table", [element("p")]),
          element("tr", [element("p")]),
          element("ul", [element("td")]),
          element("p", [element("table", [])])
        ] do
      assert {:error, [_ | _]} = JSONValidation.validate(schema, page(element))
    end
  end

  test "rejects untyped objects and text leaves masquerading as elements", %{schema: schema} do
    for element <- [
          %{},
          nil,
          1,
          [],
          %{"children" => []},
          %{"type" => "unknown"},
          %{"type" => "p"},
          %{"type" => "unknown", "text" => "bypass"},
          %{"type" => "p", "text" => "bypass"}
        ] do
      assert {:error, [_ | _]} = JSONValidation.validate(schema, page(element))
    end
  end

  test "rejects malformed known fields including nested structured content", %{schema: schema} do
    bad = [
      %{"type" => "video", "src" => [123]},
      %{"type" => "video", "src" => [%{"url" => false, "contenttype" => "video/mp4"}]},
      %{"type" => "video", "src" => [%{"url" => "video.mp4"}]},
      %{"type" => "video", "src" => [], "captions" => [%{"src" => "en.vtt"}]},
      %{"type" => "img", "caption" => [123]},
      %{"type" => "img", "children" => [element("table", [])]},
      Map.put(element("iframe"), "listen", "yes"),
      Map.put(element("command_button"), "target", 1),
      Map.put(element("command_button"), "toggleStates", [%{"title" => "missing message"}]),
      %{"type" => "definition", "term" => "term", "meanings" => [%{}]},
      %{"type" => "dialog", "lines" => [%{}]},
      %{"type" => "dialog", "speakers" => [%{}]},
      %{"type" => "dl", "items" => [%{}]},
      %{"type" => "popup", "content" => [element("p", [%{}])], "children" => [text()]},
      %{"type" => "ecl", "code" => 1, "children" => [text()]},
      Map.merge(element("trigger"), %{"trigger_type" => "page", "prompt" => "prompt"}),
      %{
        "type" => "code",
        "language" => "Text",
        "code" => false,
        "children" => [element("code_line")]
      },
      element("p", [%{"text" => "bad mark", "strong" => "true"}])
    ]

    for element <- bad,
        do: assert(match?({:error, [_ | _]}, JSONValidation.validate(schema, page(element))))
  end

  test "page metadata and containers include reports without inspecting activity models", %{
    schema: schema
  } do
    report = %{
      "type" => "report",
      "id" => "report",
      "activityId" => "activity",
      "reportType" => "likert_bar",
      "children" => []
    }

    group = %{
      "type" => "group",
      "layout" => "vertical",
      "purpose" => "none",
      "audience" => "instructor",
      "children" => [report]
    }

    content = %{
      "version" => "0.1.0",
      "bibrefs" => ["1"],
      "trigger" => %{
        "id" => "page-trigger",
        "type" => "trigger",
        "trigger_type" => "page",
        "prompt" => "Hello"
      },
      "model" => [group]
    }

    assert :ok = JSONValidation.validate(schema, content)

    assert {:error, [_ | _]} =
             JSONValidation.validate(schema, put_in(content, ["trigger", "prompt"], false))

    assert {:error, [_ | _]} =
             JSONValidation.validate(
               schema,
               put_in(content, ["trigger", "trigger_type"], "group")
             )

    assert {:error, [_ | _]} =
             JSONValidation.validate(schema, %{
               content
               | "model" => [Map.put(report, "activityId", false)]
             })

    assert {:error, [_ | _]} =
             JSONValidation.validate(schema, %{
               content
               | "model" => [Map.put(report, "children", [group])]
             })

    for {key, value} <- [{"editor", "unknown"}, {"textDirection", "up"}] do
      block = %{"type" => "content", "children" => [], key => value}
      assert {:error, [_ | _]} = JSONValidation.validate(schema, %{content | "model" => [block]})
    end
  end

  test "repository page fixtures retain their documented compatibility boundaries", %{
    schema: schema
  } do
    rejected =
      Path.wildcard("test/**/*.json")
      |> Enum.flat_map(fn path ->
        json = path |> File.read!() |> Jason.decode!()

        content =
          case json do
            %{"type" => "Page", "content" => content} -> content
            %{"model" => _} = content -> content
            _ -> nil
          end

        case content do
          %{"advancedAuthoring" => true} ->
            []

          %{"model" => model} when is_list(model) ->
            migrated = Oli.Resources.ContentMigrator.migrate(content, :page, to: :latest)

            case JSONValidation.validate(schema, migrated) do
              :ok -> []
              {:error, _} -> [path]
            end

          nil ->
            []

          _ ->
            [path]
        end
      end)

    # example_page has numeric activity-reference IDs, outside this reconciliation.
    # The other two fixtures deliberately exercise renderer error handling.
    assert rejected == [
             "test/oli/rendering/page/example_malformed_page.json",
             "test/oli/rendering/page/example_page.json",
             "test/oli/rendering/page/missing_language.json"
           ]
  end
end
