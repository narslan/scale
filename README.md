# Scale

An Elixir port-in-progress of concepts from `d3-scale`: map values from a *domain* into a *range* for visualization representetion.

## Usage

### Linear -> pixels

```elixir
s = Scale.Linear.new(domain: [0, 10], range: [0, 800])

Scale.map(s, 2.5)
#=> 200.0

Scale.invert(s, 200)
#=> {:ok, 2.5}
```

### Linear -> colors

```elixir
s =
  Scale.Linear.new(
    domain: [0, 1],
    range: [{255, 0, 0}, {0, 0, 255}],
    interpolate: &Scale.Interpolator.rgb/2
  )

Scale.map(s, 0.5)
#=> {128, 0, 128}

Scale.invert(s, {128, 0, 128})
#=> :error
```

### Ordinal -> palette lookup

```elixir
s =
  Scale.Ordinal.new(
    domain: ["a", "b", "c"],
    range: [{165, 42, 42}, {70, 130, 180}, {12, 34, 250}]
  )

Scale.map(s, "a")
#=> {165, 42, 42}
```

## Installation
Currently `scale` is not available on hex.pm.
Add `scale` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:scale, github: "narslan/scale"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/scale>.
