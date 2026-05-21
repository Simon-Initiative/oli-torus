defmodule Oli.Scenarios.Directives.ActivityBankHandlerTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  test "activity_bank directive is dispatched with a clear phase 4 runtime error" do
    yaml = """
    - activity_bank:
        project: "demo"
        ops:
          - query:
              name: "all"
    """

    directives = DirectiveParser.parse_yaml!(yaml)
    result = Engine.execute(directives)

    assert [{_directive, "activity_bank directive execution is not implemented yet"}] =
             result.errors
  end
end
