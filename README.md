# edn

An encoder to format Gleam values as [edn](https://github.com/edn-format/edn), the extensible data notation introduced and used by Clojure.

Scalar gleam values convert naturally. Compound values are represented as follows:

List
: list `(1 2 3)`

Tuple
: vector `["string" 2 true]`

Dict
: map `{["k" 1] 23 ["n" 2] 42}`

Set
: set `#{1 2 3}`

Nil and None both encode to `nil`; Some and Ok unwrap their values. Error emits a tagged value.

Custom types with no parameters encode to keywords: `:North`. Custom types with parameters encode to tagged values, with the parameter values encoded as a vector: `#Point [2 3]`.

Bit arrays are not yet encoded.

```sh
gleam add edn@1
```
```gleam
import edn

pub fn main() {
  let s = edn.format(#("whatever", 3))
}
```

## Development

```sh
gleam test
```

I wrote this mostly as a learning exercise and to provide a terser
representation of the mess of dicts and sets comprising my Advent of Code
solutions than that afforded by `io/debug`, mostly by adapting the `pprint`
decoder package. That said, it seems like a useful package to develop, and I'd
be happy to collaborative with anyone who shares this interest.