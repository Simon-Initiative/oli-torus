defmodule Oli.Delivery.Evaluation.Parser do

  @moduledoc """
  A parser for evaluation rules.

  The macros present here end up defining a single public function
  `rule` in this module that takes a string input and attempts to parse
  the following grammar:

  <rule> :== <expression> {<or> <expression>}
  <expression> :== <clause> {<and> <clause>}
  <clause> :== <not><clause> | "("<rule>")” | <criterion>
  <criterion> :== <component> <operator> <value>
  <component> :== "attemptNumber” | "input” | "length(input)"
  <operator> :== "<” | ">” | "=" | "like"
  <value> :== { string }
  <not> :== "!"
  <and> :== "&&"
  <or>  :== "||"

  """

  import NimbleParsec

  not_ = string("!") |> replace(:!) |> label("!")
  and_ = string("&&") |> optional(string(" ")) |> replace(:&&) |> label("&&")
  or_ = string("||") |> optional(string(" ")) |> replace(:||) |> label("||")
  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> optional(string(" ")) |> label(")")
  lbrace = ascii_char([?{]) |> label("{")
  rbrace = ascii_char([?}]) |> optional(string(" ")) |> label("}")
  op_lt = ascii_char([?<]) |> optional(string(" ")) |> replace(:lt) |> label("<")
  op_gt = ascii_char([?>]) |> optional(string(" ")) |> replace(:gt) |>label(">")
  op_eq = ascii_char([?=]) |> optional(string(" ")) |> replace(:eq) |>label("=")
  op_like = string("like") |> optional(string(" ")) |> replace(:like) |> label("like")


  defcombinatorp :string_until_rbrace,
            repeat(
              lookahead_not(ascii_char([?}]))
              |> utf8_char([])
            )
            |> reduce({List, :to_string, []})

  defcombinatorp(:value, ignore(lbrace) |> parsec(:string_until_rbrace) |> ignore(rbrace))


  # <component> :== "attemptNumber" | "input" | "length(input)"
  attempt_number_ = string("attemptNumber") |> optional(string(" ")) |> replace(:attempt_number) |> label("attemptNumber")
  input_ = string("input") |> optional(string(" ")) |> replace(:input) |> label("input")
  input_length_ = string("length(input)") |> optional(string(" ")) |> replace(:input_length) |> label("input_length")
  defcombinatorp(:component, choice([attempt_number_, input_, input_length_]))

  # <operator> :== "<" | ">" | "=" | "like"
  defcombinatorp(:operator, choice([op_lt, op_gt, op_eq, op_like]))

  # <criterion> :== <component> <operator> <check>
  defcombinatorp(
    :criterion,
    parsec(:component)
    |> parsec(:operator)
    |> parsec(:value)
    |> reduce(:to_prefix_notation)
  )

  # <clause> :== <not> <clause> | "(" <rule> ")" | <criterion>
  negation = not_ |> ignore |> parsec(:clause) |> tag(:!)
  grouping = ignore(lparen) |> parsec(:rule) |> ignore(rparen)
  criterion_ = parsec(:criterion)
  defcombinatorp(:clause, choice([negation, grouping, criterion_]))

  # <expression> :== <clause> {<and> <clause>}
  defcombinatorp(
    :expression,
    parsec(:clause)
    |> repeat(and_ |> parsec(:clause))
    |> reduce(:to_prefix_notation)
  )

  # <rule> :== <expression> {<or> <expression>}
  defparsec(
    :rule,
    parsec(:expression)
    |> repeat(or_ |> parsec(:expression))
    |> reduce(:to_prefix_notation)
  )

  defp to_prefix_notation(acc) do
    case acc do
      [lhs, op, rhs] -> {op, lhs, rhs}
      [f, o] -> {:eval, f, o}
      [!: [negated]] -> {:!, negated}
      [item] -> item
    end
  end
end
