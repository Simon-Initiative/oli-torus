import expression
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn hello_test() {
  assert expression.hello("Torus") == "Hello from Gleam, Torus!"
}

pub fn parse_test() {
  assert expression.parse("1 + 2") == Ok("parsed: 1 + 2")
}
