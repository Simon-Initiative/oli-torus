defmodule Oli.Delivery.Evaluation.Rule do

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

  # <check> :== <function> "{" <input> "}"

  numeric_ = string("numeric") |> replace(:numeric) |> label("numeric")
  length_ = string("length") |> replace(:length) |> label("length")
  regex_ = string("regex") |> replace(:regex) |> label("regex")


  defcombinatorp :string_until_rbrace,
            repeat(
              lookahead_not(ascii_char([?}]))
              |> utf8_char([])
            )
            |> reduce({List, :to_string, []})

  defcombinatorp(:function, choice([numeric_, length_, regex_]))

  defcombinatorp(:operands, ignore(lbrace) |> parsec(:string_until_rbrace) |> ignore(rbrace))


  defcombinatorp(:check, parsec(:function)
  |> parsec(:operands)
  |> reduce(:fold_infixl))


  # <component> :== "attemptNumber" | "input"
  attempt_number_ = string("attemptNumber") |> optional(string(" ")) |> replace(:attempt_number) |> label("attemptNumber")
  input_ = string("input") |> optional(string(" ")) |> replace(:input) |> label("input")
  defcombinatorp(:component, choice([attempt_number_, input_]))

  # <operator> :== "<" | ">" | "="
  defcombinatorp(:operator, choice([op_lt, op_gt, op_eq]))

  # <criterion> :== <component> <operator> <check>
  defcombinatorp(
    :criterion,
    parsec(:component)
    |> parsec(:operator)
    |> parsec(:check)
    |> reduce(:fold_infixl)
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
    |> reduce(:fold_infixl)
  )

  # <rule> :== <expression> {<or> <expression>}
  defparsec(
    :rule,
    parsec(:expression)
    |> repeat(or_ |> parsec(:expression))
    |> reduce(:fold_infixl)
  )

  defp fold_infixl(acc) do
    case acc do
      [lhs, op, rhs] -> {op, lhs, rhs}
      [f, o] -> {:eval, f, o}
      [!: [negated]] -> {:!, negated}
      [item] -> item
    end
  end
end
