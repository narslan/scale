defmodule Scale.Linear do
  @moduledoc """
  A continuous scale mapping a numeric domain to a continuous range.

  The default interpolator is `Scale.Interpolator.lerp/2`.

  ## Pixels

      iex> s = Scale.Linear.new(domain: [0, 10], range: [0, 800])
      iex> Scale.map(s, 2.5)
      200.0

  ## Colors

      iex> s = Scale.Linear.new(domain: [0, 1], range: [{255, 0, 0}, {0, 0, 255}], interpolate: &Scale.Interpolator.rgb/2)
      iex> Scale.map(s, 0.5)
      {128, 0, 128}
      iex> Scale.invert(s, {128, 0, 128})
      {:error, :invalid_range}
  """

  alias Scale.Interpolator

  defstruct domain: [0.0, 1.0],
            range: [0.0, 1.0],
            interpolate: &Interpolator.lerp/2,
            clamp: false

  @type t :: %__MODULE__{
          domain: [number()],
          range: [any()],
          interpolate: Interpolator.t(),
          clamp: boolean()
        }

  @spec new(keyword()) :: t()
  @doc """
  Builds a new linear scale.

  ## Options

  - `:domain` (2-element list/tuple of numbers, default: `[0.0, 1.0]`)
  - `:range` (2-element list/tuple, default: `[0.0, 1.0]`)
  - `:interpolate` (`(a, b -> (t -> value))`, default: `&Scale.Interpolator.lerp/2`)
    Interpolator used for the range endpoints.
  - `:clamp` (boolean, default: `false`) when `true`, clamps the computed `t`
    into `[0.0, 1.0]` before interpolation.
  """
  def new(opts \\ []) do
    domain = opts |> Keyword.get(:domain, [0.0, 1.0]) |> normalize_pair!(:domain)
    range = opts |> Keyword.get(:range, [0.0, 1.0]) |> normalize_pair!(:range)

    %__MODULE__{
      domain: domain,
      range: range,
      interpolate: Keyword.get(opts, :interpolate, &Interpolator.lerp/2),
      clamp: Keyword.get(opts, :clamp, false)
    }
  end

  @spec set_domain(t(), [number()] | {number(), number()}) :: t()
  def set_domain(%__MODULE__{} = scale, domain),
    do: %{scale | domain: normalize_pair!(domain, :domain)}

  @spec set_range(t(), [any()] | {any(), any()}) :: t()
  def set_range(%__MODULE__{} = scale, range),
    do: %{scale | range: normalize_pair!(range, :range)}

  @spec set_interpolate(t(), Interpolator.t()) :: t()
  def set_interpolate(%__MODULE__{} = scale, interpolate) when is_function(interpolate, 2),
    do: %{scale | interpolate: interpolate}

  @spec set_clamp(t(), boolean()) :: t()
  def set_clamp(%__MODULE__{} = scale, clamp) when is_boolean(clamp),
    do: %{scale | clamp: clamp}

  defp normalize_pair!({a, b}, _label), do: [a, b]

  defp normalize_pair!([a, b], label) do
    case label do
      :domain ->
        if is_number(a) and is_number(b) do
          [a, b]
        else
          raise ArgumentError, "Scale.Linear domain endpoints must be numbers, got: #{inspect([a, b])}"
        end

      _ ->
        [a, b]
    end
  end

  defp normalize_pair!(other, label) do
    raise ArgumentError, "Scale.Linear #{label} must be a 2-element list/tuple, got: #{inspect(other)}"
  end
end

defimpl Scale, for: Scale.Linear do
  @moduledoc false

  def domain(%Scale.Linear{domain: domain}), do: domain
  def range(%Scale.Linear{range: range}), do: range

  def map(%Scale.Linear{domain: [d0, d1], range: [r0, r1], interpolate: interpolate, clamp: clamp}, x)
      when is_number(x) do
    t = t_from_pair(d0, d1, x)
    t = if clamp, do: clamp01(t), else: t
    interpolate.(r0, r1).(t)
  end

  def map(%Scale.Linear{}, x) do
    raise ArgumentError, "Scale.Linear expects a numeric input, got: #{inspect(x)}"
  end

  def invert(%Scale.Linear{domain: [d0, d1], range: [r0, r1], clamp: clamp}, y)
      when is_number(r0) and is_number(r1) and is_number(y) do
    denom = r1 - r0

    if denom == 0 do
      {:error, :invalid_range}
    else
      t = (y - r0) / denom
      t = if clamp, do: clamp01(t), else: t
      {:ok, d0 + t * (d1 - d0)}
    end
  end

  def invert(%Scale.Linear{}, _y), do: {:error, :invalid_range}

  defp t_from_pair(a, b, x) do
    denom = b - a
    if denom == 0, do: 0.0, else: (x - a) / denom
  end

  defp clamp01(t) when t < 0.0, do: 0.0
  defp clamp01(t) when t > 1.0, do: 1.0
  defp clamp01(t), do: t * 1.0
end
