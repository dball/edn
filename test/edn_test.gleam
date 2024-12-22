import edn
import gleam/dict
import gleam/option.{None, Some}
import gleam/set
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn format_string_test() {
  edn.format("foo") |> should.equal("\"foo\"")
  edn.format("\"foo\"") |> should.equal("\"\\\"foo\\\"\"")
  edn.format("foo\nbar") |> should.equal("\"foo\\nbar\"")
}

pub fn format_bool_test() {
  edn.format(True) |> should.equal("true")
  edn.format(False) |> should.equal("false")
}

pub fn format_list_test() {
  edn.format([1, 3, 5]) |> should.equal("(1 3 5)")
}

pub fn format_dict_test() {
  edn.format(dict.from_list([#("a", 1), #("b", 2)]))
  |> should.equal("{\"a\" 1, \"b\" 2}")
}

pub fn format_tuple_test() {
  edn.format(#("foo", 1, True)) |> should.equal("[\"foo\" 1 true]")
}

type Custom {
  EnumCase
  UnaryLabelCase(name: String)
  UnaryPosnCase(String)
  MultiCase(name: String, hats: Int)
}

pub fn format_custom_test() {
  edn.format(EnumCase) |> should.equal(":EnumCase")
  edn.format(UnaryLabelCase("foo"))
  |> should.equal("#UnaryLabelCase \"foo\"")
  edn.format(UnaryPosnCase("foo"))
  |> should.equal("#UnaryPosnCase \"foo\"")
  edn.format(MultiCase(name: "foo", hats: 3))
  |> should.equal("#MultiCase [\"foo\" 3]")
}

pub fn format_set_test() {
  edn.format(set.from_list([1, 3, 5])) |> should.equal("#{1 3 5}")
}

pub fn format_option_test() {
  edn.format(Some("pig")) |> should.equal("\"pig\"")
  edn.format(None) |> should.equal("nil")
}

pub fn format_error_test() {
  edn.format(Ok("cupid")) |> should.equal("\"cupid\"")
  edn.format(Error(Nil)) |> should.equal("#Error nil")
}
