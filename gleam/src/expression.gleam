pub fn hello(name: String) -> String {
  "Hello from Gleam, " <> name <> "!"
}

pub fn parse(expression: String) -> Result(String, String) {
  Ok("parsed: " <> expression)
}
