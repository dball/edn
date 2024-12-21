import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/json
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree
import pprint/decoder

pub type Config {
  Config
}

pub fn debug(value: a) -> a {
  value |> with_config(Config) |> io.println_error
  value
}

pub fn format(value: a) -> String {
  with_config(value, Config)
}

pub fn with_config(value: a, config: Config) -> String {
  value |> dynamic.from |> format_dynamic(config)
}

fn format_dynamic(value: Dynamic, config: Config) -> String {
  value |> decoder.classify |> format_type(config)
}

fn format_type(value: decoder.Type, config: Config) -> String {
  case value {
    decoder.TString(v) -> json.string(v) |> json.to_string
    decoder.TInt(v) -> int.to_string(v)
    decoder.TFloat(v) -> float.to_string(v)
    decoder.TBool(v) ->
      case v {
        True -> "true"
        False -> "false"
      }
    decoder.TBitArray(v) -> todo
    decoder.TNil -> "nil"
    decoder.TList(v) -> format_list(v, config)
    decoder.TDict(v) -> format_dict(v, config)
    decoder.TTuple(v) -> format_tuple(v, config)
    decoder.TCustom(name, fields) -> format_custom(name, fields, config)
    decoder.TForeign(v) -> format_foreign(v, config)
  }
}

fn format_list(items: List(Dynamic), config: Config) -> String {
  let st = string_tree.new() |> string_tree.append("(")
  list.index_fold(items, st, fn(st, item, i) {
    let value = format_dynamic(item, config)
    case i {
      0 -> st
      _ -> string_tree.append(st, " ")
    }
    |> string_tree.append(value)
  })
  |> string_tree.append(")")
  |> string_tree.to_string
}

fn format_dict(
  items: Dict(decoder.Type, decoder.Type),
  config: Config,
) -> String {
  let st = string_tree.new() |> string_tree.append("{")
  dict.to_list(items)
  |> list.sort(fn(a, b) {
    let #(ka, _) = a
    let #(kb, _) = b
    // TODO if we do render these keys, maybe keep
    // them around so we don't repeat work in the fold
    string.compare(format_type(ka, config), format_type(kb, config))
  })
  |> list.index_fold(st, fn(st, entry, i) {
    // TODO keywords would be more idiomatic
    // if keys are strings. Maybe a config option.
    let key = format_type(entry.0, config)
    let value = format_type(entry.1, config)
    case i {
      0 -> st
      _ -> string_tree.append(st, ", ")
    }
    |> string_tree.append(key)
    |> string_tree.append(" ")
    |> string_tree.append(value)
  })
  |> string_tree.append("}")
  |> string_tree.to_string
}

fn format_tuple(items: List(Dynamic), config: Config) -> String {
  // TODO this is just format_list with square brackets
  let st = string_tree.new() |> string_tree.append("[")
  list.index_fold(items, st, fn(st, item, i) {
    let value = format_dynamic(item, config)
    case i {
      0 -> st
      _ -> string_tree.append(st, " ")
    }
    |> string_tree.append(value)
  })
  |> string_tree.append("]")
  |> string_tree.to_string
}

type CustomFields {
  AllLabelled
  AllPositional
  Mixed
}

fn classify_custom_fields(fields: List(decoder.Field)) -> Option(CustomFields) {
  list.fold_until(fields, None, fn(accum, field) {
    let value = case field {
      decoder.Labelled(_, _) -> AllLabelled
      decoder.Positional(_) -> AllPositional
    }
    case accum {
      None -> Continue(Some(value))
      Some(accum) if accum == value -> Continue(Some(value))
      _ -> Stop(Some(Mixed))
    }
  })
}

fn format_custom(
  name: String,
  fields: List(decoder.Field),
  config: Config,
) -> String {
  // TODO this is fine, but: we would really like to allow in the config
  // to let callers specify explicit tag encoding for their own types.
  // For example: birl.Time is maybe the natural host type for #inst,
  // but we don't want to depend on birl here. How to allow?
  case name {
    "Set" -> format_custom_set(fields, config)
    "Some" -> format_custom_some(fields, config)
    "None" -> format_custom_none(fields, config)
    "Ok" -> format_custom_ok(fields, config)
    "Error" -> format_custom_error(fields, config)
    _ -> format_custom_general(name, fields, config)
  }
}

fn format_custom_set(fields: List(decoder.Field), config: Config) -> String {
  let assert [decoder.Positional(vs)] = fields
  let assert decoder.TDict(vs) = decoder.classify(vs)
  let st = string_tree.new() |> string_tree.append("#{")
  dict.keys(vs)
  // TODO maybe sort by v, but how?
  |> list.index_fold(st, fn(st, v, i) {
    case i {
      0 -> st
      _ -> string_tree.append(st, " ")
    }
    |> string_tree.append(format_type(v, config))
  })
  |> string_tree.append("}")
  |> string_tree.to_string
}

fn format_custom_some(fields: List(decoder.Field), config: Config) -> String {
  let assert [decoder.Positional(v)] = fields
  // TODO we could choose tag, or just unwrap like we're doing here
  format_dynamic(v, config)
}

fn format_custom_none(fields: List(decoder.Field), _config: Config) -> String {
  let assert [] = fields
  // TODO similarly, we could tag this
  "nil"
}

fn format_custom_ok(fields: List(decoder.Field), config: Config) -> String {
  let assert [decoder.Positional(v)] = fields
  // TODO we could choose tag, or just unwrap like we're doing here
  format_dynamic(v, config)
}

fn format_custom_error(fields: List(decoder.Field), config: Config) -> String {
  let assert [decoder.Positional(v)] = fields
  // Seems important to keep the error claim
  "#gleam/Error " <> format_dynamic(v, config)
}

// TODO does beam/gleam have package namespaces
fn format_custom_general(
  name: String,
  fields: List(decoder.Field),
  config: Config,
) -> String {
  let name = "gleam/" <> name
  case fields {
    [] -> ":" <> name
    [field] ->
      "#"
      <> name
      <> " "
      <> format_dynamic(
        case field {
          decoder.Labelled(_, value) -> value
          decoder.Positional(value) -> value
        },
        config,
      )
    _ -> {
      let assert Some(mode) = classify_custom_fields(fields)
      case mode {
        AllLabelled -> {
          let kvs =
            list.map(fields, fn(field) {
              let assert decoder.Labelled(k, v) = field
              #(dynamic.from(k), v)
            })
            |> dict.from_list
          // TODO if we ever get here, we probably want keyword ks
          // So probably a config option is motivated
          "#" <> name <> " " <> with_config(kvs, config)
        }
        AllPositional -> {
          let st = string_tree.new() |> string_tree.append("#" <> name <> " [")
          list.index_fold(fields, st, fn(st, field, i) {
            let assert decoder.Positional(v) = field
            case i {
              0 -> st
              _ -> string_tree.append(st, " ")
            }
            |> string_tree.append(format_dynamic(v, config))
          })
          |> string_tree.append("]")
          |> string_tree.to_string
        }
        Mixed -> todo
      }
    }
  }
}

fn format_foreign(value: String, _config: Config) -> String {
  "#gleam/Foreign " <> json.string(value) |> json.to_string
}
