# Scale

An Elixir port-in-progress of concepts from `d3-scale`: map values from a *domain* into a *range* for visualization representation.

## Usage

### Linear -> numbers/pixel coordinates

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
#=> {:error, :invalid_range}
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

### Quantize -> buckets

```elixir
s = Scale.Quantize.new(domain: [0, 100], range: [:a, :b, :c, :d, :e])
Scale.map(s, 20)
#=> :b
```

### Band -> uniform bands (rows/bars)

```elixir
s = Scale.Band.new(domain: [:row1, :row2, :row3], range: [0, 300], padding_inner: 0.1)

y = Scale.map(s, :row2)
h = Scale.Band.bandwidth(s)
```

## Installation
Add `scale` to your list of dependencies in `mix.exs`:
Currently `scale` is not available on hex.pm.
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
