defmodule Scale.Band do
  @moduledoc """
  A discrete (categorical) scale that maps values onto *uniform bands* in a
  continuous numeric range.

  This is analogous to `d3.scaleBand`. It’s useful for bar charts, table rows,
  and any evenly spaced layout.

  `Scale.map/2` returns the **start position** of the band for a domain value.
  Use `bandwidth/1` to get the band size.

  Values not present in the domain map to `nil`.

  `invert/2` is not supported and returns `{:error, :not_invertible}`.

  ## Example

      iex> s = Scale.Band.new(domain: [:a, :b, :c], range: [0, 300])
      iex> Scale.map(s, :a)
      0.0
      iex> Scale.map(s, :b)
      100.0
      iex> Scale.Band.bandwidth(s)
      100.0
  """

  @enforce_keys [
    :domain,
    :range,
    :padding_inner,
    :padding_outer,
    :align,
    :round,
    :index,
    :step,
    :bandwidth
  ]
  defstruct domain: [],
            range: [0.0, 1.0],
            padding_inner: 0.0,
            padding_outer: 0.0,
            align: 0.5,
            round: false,
            index: %{},
            step: 0.0,
            bandwidth: 0.0

  @type t :: %__MODULE__{
          domain: [any()],
          range: [number()],
          padding_inner: number(),
          padding_outer: number(),
          align: number(),
          round: boolean(),
          index: %{optional(any()) => number()},
          step: float(),
          bandwidth: float()
        }

  @spec new(keyword()) :: t()
  @doc """
  Builds a new band scale.

  ## Options

  - `:domain` (list, default: `[]`) discrete values (categories) to place into bands.
  - `:range` (2-element list/tuple of numbers, default: `[0.0, 1.0]`) output interval.
    Can be ascending (`[0, 300]`) or descending (`[300, 0]`).
  - `:padding` (number >= 0, default: `0.0`) convenience that sets both
    `:padding_inner` and `:padding_outer`.
  - `:padding_inner` (number >= 0, default: `0.0`) fraction of the step reserved
    as space between bands. Bandwidth is `step * (1 - padding_inner)`.
  - `:padding_outer` (number >= 0, default: `0.0`) outer padding expressed in
    multiples of the step.
  - `:align` (number in `[0, 1]`, default: `0.5`) how to distribute any leftover
    space within the range: `0.0` start, `0.5` centered, `1.0` end.
  - `:round` (boolean, default: `false`) if `true`, rounds the computed start and
    bandwidth to integers (useful for pixel alignment).

  ## Derived values

  - `bandwidth/1` returns the width/height of each band.
  - `step/1` returns the distance between the starts of adjacent bands.

  ## Internal fields

  - `:index` is a cached map from each domain value to its computed band start
    position (built automatically; not an option).
  ## Notes

  - `Scale.map/2` returns the **band start** (not the center).
  - Use `bandwidth/1` for the band height/width.

    In a band scale, each category maps to a band interval in your numeric range, not a single "point".

    Examples:

        s = Scale.Band.new(domain: [:a, :b, :c], range: [0, 300])
        Scale.Band.bandwidth(s) #=> 100.0
        Scale.map(s, :b)        #=> 100.0

  Here `:b` occupies the interval `[100.0, 200.0)`.   
  `Scale.map(s, :b)` returns `100.0`, the left/top edge (the band start).   
  The center would be `100.0 + bandwidth/2 -> 150.0`.

  So for:

  - drawing a bar/row rectangle: use x_or_y = Scale.map(s, key) and w_or_h = Scale.Band.bandwidth(s)
  - drawing a label centered in the band: use Scale.map(s, key) + Scale.Band.bandwidth(s) / 2
  """
  def new(opts \\ []) do
    domain = Keyword.get(opts, :domain, [])
    range = opts |> Keyword.get(:range, [0.0, 1.0]) |> normalize_range!()

    unless is_list(domain),
      do: raise(ArgumentError, "Scale.Band domain must be a list, got: #{inspect(domain)}")

    padding_inner = Keyword.get(opts, :padding_inner, Keyword.get(opts, :padding, 0.0))
    padding_outer = Keyword.get(opts, :padding_outer, Keyword.get(opts, :padding, 0.0))
    align = Keyword.get(opts, :align, 0.5)
    round = Keyword.get(opts, :round, false)

    scale = %__MODULE__{
      domain: domain,
      range: range,
      padding_inner: normalize_padding!(padding_inner, :padding_inner),
      padding_outer: normalize_padding!(padding_outer, :padding_outer),
      align: normalize_align!(align),
      round: normalize_round!(round),
      index: %{},
      step: 0.0,
      bandwidth: 0.0
    }

    rescale(scale)
  end

  @spec set_domain(t(), [any()]) :: t()
  def set_domain(%__MODULE__{} = scale, domain) when is_list(domain),
    do: rescale(%{scale | domain: domain})

  @spec set_range(t(), [number()] | {number(), number()}) :: t()
  def set_range(%__MODULE__{} = scale, range),
    do: rescale(%{scale | range: normalize_range!(range)})

  @spec set_padding(t(), number()) :: t()
  def set_padding(%__MODULE__{} = scale, padding) do
    padding = normalize_padding!(padding, :padding)
    rescale(%{scale | padding_inner: padding, padding_outer: padding})
  end

  @spec set_padding_inner(t(), number()) :: t()
  def set_padding_inner(%__MODULE__{} = scale, padding_inner),
    do: rescale(%{scale | padding_inner: normalize_padding!(padding_inner, :padding_inner)})

  @spec set_padding_outer(t(), number()) :: t()
  def set_padding_outer(%__MODULE__{} = scale, padding_outer),
    do: rescale(%{scale | padding_outer: normalize_padding!(padding_outer, :padding_outer)})

  @spec set_align(t(), number()) :: t()
  def set_align(%__MODULE__{} = scale, align),
    do: rescale(%{scale | align: normalize_align!(align)})

  @spec set_round(t(), boolean()) :: t()
  def set_round(%__MODULE__{} = scale, round),
    do: rescale(%{scale | round: normalize_round!(round)})

  @spec bandwidth(t()) :: float()
  def bandwidth(%__MODULE__{bandwidth: bandwidth}), do: bandwidth

  @spec step(t()) :: float()
  def step(%__MODULE__{step: step}), do: step

  defp normalize_range!({a, b}) when is_number(a) and is_number(b), do: [a, b]
  defp normalize_range!([a, b]) when is_number(a) and is_number(b), do: [a, b]

  defp normalize_range!(other) do
    raise ArgumentError,
          "Scale.Band range must be a 2-element list/tuple of numbers, got: #{inspect(other)}"
  end

  defp normalize_padding!(p, _label) when is_number(p) and p >= 0, do: p * 1.0

  defp normalize_padding!(p, label) do
    raise ArgumentError, "Scale.Band #{label} must be a number >= 0, got: #{inspect(p)}"
  end

  defp normalize_align!(a) when is_number(a) and a >= 0 and a <= 1, do: a * 1.0

  defp normalize_align!(a) do
    raise ArgumentError, "Scale.Band align must be a number in [0, 1], got: #{inspect(a)}"
  end

  defp normalize_round!(b) when is_boolean(b), do: b

  defp normalize_round!(other),
    do: raise(ArgumentError, "Scale.Band round must be boolean, got: #{inspect(other)}")

  defp rescale(%__MODULE__{} = scale) do
    n = length(scale.domain)
    reverse? = Enum.at(scale.range, 1) < Enum.at(scale.range, 0)

    {start, stop} =
      if reverse?,
        do: {Enum.at(scale.range, 1) * 1.0, Enum.at(scale.range, 0) * 1.0},
        else: {Enum.at(scale.range, 0) * 1.0, Enum.at(scale.range, 1) * 1.0}

    padding_inner = scale.padding_inner
    padding_outer = scale.padding_outer
    align = scale.align

    step =
      if n == 0 do
        0.0
      else
        denom = max(1.0, n - padding_inner + padding_outer * 2.0)
        (stop - start) / denom
      end

    step = if scale.round, do: :math.floor(step), else: step

    start =
      if n == 0 do
        start
      else
        start + (stop - start - step * (n - padding_inner)) * align
      end

    bandwidth = step * (1.0 - padding_inner)

    {start, bandwidth} =
      if scale.round do
        {:erlang.round(start * 1.0), :erlang.round(bandwidth * 1.0)}
      else
        {start, bandwidth}
      end

    positions =
      if n == 0 do
        []
      else
        for i <- 0..(n - 1), do: start + step * i
      end

    positions = if reverse?, do: Enum.reverse(positions), else: positions

    index =
      scale.domain
      |> Enum.zip(positions)
      |> Map.new()

    %{scale | index: index, step: step * 1.0, bandwidth: bandwidth * 1.0}
  end
end

defimpl Scale, for: Scale.Band do
  @moduledoc false

  def domain(%Scale.Band{domain: domain}), do: domain
  def range(%Scale.Band{range: range}), do: range

  def map(%Scale.Band{index: index}, value) do
    Map.get(index, value)
  end

  def invert(%Scale.Band{}, _value), do: {:error, :not_invertible}
end
