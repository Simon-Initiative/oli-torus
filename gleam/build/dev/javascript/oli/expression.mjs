/// <reference types="./expression.d.mts" />
import { Ok } from "./gleam.mjs";

export function hello(name) {
  return ("Hello from Gleam, " + name) + "!";
}

export function parse(expression) {
  return new Ok("parsed: " + expression);
}
