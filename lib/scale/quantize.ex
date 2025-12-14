defmodule Scale.Quantize do
  @moduledoc """
  A continuous (numeric) domain mapped onto a discrete range.

  This is analogous to `d3.scaleQuantize`: the domain `[d0, d1]` is split into
  `n = length(range)` uniform buckets and `map/2` returns the bucket's range
  value.

  Values outside the domain clamp to the first/last range value.

  `invert/2` is not one-to-one for quantized outputs, so it returns the domain
  *extent* for a given range value as `{:ok, {x0, x1}}` (or `:error` if the
  value isn't present in the range).

  ## Example

      iex> s = Scale.Quantize.new(domain: [0, 100], range: [:a, :b, :c, :d, :e])
      iex> Scale.map(s, 0)
      :a
      iex> Scale.map(s, 20)
      :b
      iex> Scale.map(s, 99.9)
      :e
      iex> Scale.map(s, 200)
      :e
      iex> Scale.invert(s, :c)
      {:ok, {40.0, 60.0}}
  """

  @enforce_keys [:domain, :range]
  defstruct domain: [0.0, 1.0],
            range: []

  @type t :: %__MODULE__{
          domain: [number()],
          range: [any()]
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    domain = opts |> Keyword.get(:domain, [0.0, 1.0]) |> normalize_domain!()
    range = Keyword.get(opts, :range, [])

    unless is_list(range),
      do: raise(ArgumentError, "Scale.Quantize range must be a list, got: #{inspect(range)}")

    %__MODULE__{domain: domain, range: range}
  end

  @spec set_domain(t(), [number()] | {number(), number()}) :: t()
  def set_domain(%__MODULE__{} = scale, domain), do: %{scale | domain: normalize_domain!(domain)}

  @spec set_range(t(), [any()]) :: t()
  def set_range(%__MODULE__{} = scale, range) when is_list(range), do: %{scale | range: range}

  defp normalize_domain!({a, b}), do: normalize_domain!([a, b])

  defp normalize_domain!([a, b]) when is_number(a) and is_number(b), do: [a, b]

  defp normalize_domain!(other) do
    raise ArgumentError, "Scale.Quantize domain must be a 2-element list/tuple of numbers, got: #{inspect(other)}"
  end
end

defimpl Scale, for: Scale.Quantize do
  def domain(%Scale.Quantize{domain: domain}), do: domain
  def range(%Scale.Quantize{range: range}), do: range

  def map(%Scale.Quantize{domain: [d0, d1], range: range}, x) when is_number(x) do
    case range do
      [] ->
        nil

      _ ->
        n = length(range)

        cond do
          d0 == d1 ->
            hd(range)

          x <= d0 ->
            hd(range)

          x >= d1 ->
            List.last(range)

          true ->
            t = (x - d0) / (d1 - d0)
            idx = trunc(:math.floor(t * n))
            idx = if idx >= n, do: n - 1, else: idx
            Enum.at(range, idx)
        end
    end
  end

  def map(%Scale.Quantize{}, x) do
    raise ArgumentError, "Scale.Quantize expects a numeric input, got: #{inspect(x)}"
  end

  def invert(%Scale.Quantize{domain: [d0, d1], range: range}, value) do
    n = length(range)

    cond do
      n == 0 ->
        {:error, :invalid_range}

      d0 == d1 ->
        {:error, :invalid_domain}

      true ->
        case Enum.find_index(range, &(&1 == value)) do
          nil ->
            {:error, :unknown_range_value}

          idx ->
            step = (d1 - d0) / n
            x0 = d0 + step * idx
            x1 = if idx == n - 1, do: d1 * 1.0, else: d0 + step * (idx + 1)
            {:ok, {x0 * 1.0, x1 * 1.0}}
        end
    end
  end
end
