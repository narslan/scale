defmodule Scale.Interpolator do
  @moduledoc """
  Interpolators for scale ranges.

  An interpolator is a function that takes two range endpoints and returns a
  function of `t` (typically a normalized parameter where `0.0` means "start"
  and `1.0` means "end").

  Interpolators generally accept any number to allow extrapolation.
  """

  @type t :: (any(), any() -> (number() -> any()))

  @doc """
  Linear interpolation (lerp) for numbers and numeric tuples/lists.

      iex> i = Scale.Interpolator.lerp(0, 10)
      iex> i.(0.25)
      2.5

      iex> i = Scale.Interpolator.lerp({0, 0}, {10, 20})
      iex> i.(0.5)
      {5.0, 10.0}
  """
  @spec lerp(any(), any()) :: (number() -> any())
  def lerp(a, b) when is_number(a) and is_number(b) do
    fn t -> a + (b - a) * t end
  end

  def lerp(a, b) when is_tuple(a) and is_tuple(b) and tuple_size(a) == tuple_size(b) do
    a_list = Tuple.to_list(a)
    b_list = Tuple.to_list(b)

    lerp(a_list, b_list)
    |> then(fn list_interp -> fn t -> list_interp.(t) |> List.to_tuple() end end)
  end

  def lerp(a, b) when is_list(a) and is_list(b) and length(a) == length(b) do
    interps = Enum.zip_with(a, b, &lerp/2)
    fn t -> Enum.map(interps, & &1.(t)) end
  end

  def lerp(a, b) do
    raise ArgumentError,
          "Scale.Interpolator.lerp/2 expects numbers or same-sized tuples/lists, got: #{inspect(a)} and #{inspect(b)}"
  end

  @doc """
  RGB interpolation for `{r, g, b}` tuples (0..255), returning rounded integers.

      iex> i = Scale.Interpolator.rgb({255, 0, 0}, {0, 0, 255})
      iex> i.(0.5)
      {128, 0, 128}
  """
  @spec rgb({number(), number(), number()}, {number(), number(), number()}) :: (number() ->
                                                                                  {integer(),
                                                                                   integer(),
                                                                                   integer()})
  def rgb({r0, g0, b0}, {r1, g1, b1}) do
    ir = lerp(r0, r1)
    ig = lerp(g0, g1)
    ib = lerp(b0, b1)

    fn t ->
      {
        ir.(t) |> round() |> clamp_int(0, 255),
        ig.(t) |> round() |> clamp_int(0, 255),
        ib.(t) |> round() |> clamp_int(0, 255)
      }
    end
  end

  @doc """
  OKLab interpolation for `{r, g, b}` tuples (0..255), returning rounded integers.

  This typically produces smoother gradients than naïve RGB interpolation.

      iex> i = Scale.Interpolator.oklab({255, 0, 0}, {0, 0, 255})
      iex> i.(0.0)
      {255, 0, 0}
      iex> i.(1.0)
      {0, 0, 255}
  """
  @spec oklab({number(), number(), number()}, {number(), number(), number()}) :: (number() ->
                                                                                    {integer(),
                                                                                     integer(),
                                                                                     integer()})
  def oklab(c0, c1) do
    {l0, a0, b0} = srgb255_to_oklab(c0)
    {l1, a1, b1} = srgb255_to_oklab(c1)

    i_l = lerp(l0, l1)
    i_a = lerp(a0, a1)
    i_b = lerp(b0, b1)

    fn t -> oklab_to_srgb255({i_l.(t), i_a.(t), i_b.(t)}) end
  end

  @doc """
  OKLCH interpolation for `{r, g, b}` tuples (0..255), returning rounded integers.

  Interpolates in OKLab's polar form (lightness/chroma/hue). Hue interpolation
  follows the shortest angular distance.

      iex> i = Scale.Interpolator.oklch({255, 0, 0}, {0, 0, 255})
      iex> i.(0.0)
      {255, 0, 0}
      iex> i.(1.0)
      {0, 0, 255}
  """
  @spec oklch({number(), number(), number()}, {number(), number(), number()}) :: (number() ->
                                                                                    {integer(),
                                                                                     integer(),
                                                                                     integer()})
  def oklch(c0, c1) do
    {l0, c0c, h0} = srgb255_to_oklch(c0)
    {l1, c1c, h1} = srgb255_to_oklch(c1)

    {h0, h1} = normalize_hues({c0c, h0}, {c1c, h1})

    i_l = lerp(l0, l1)
    i_c = lerp(c0c, c1c)
    i_h = lerp_angle(h0, h1)

    fn t -> oklch_to_srgb255({i_l.(t), i_c.(t), i_h.(t)}) end
  end

  defp normalize_hues({c0, h0}, {c1, h1}) do
    eps = 1.0e-12

    cond do
      c0 <= eps and c1 <= eps -> {0.0, 0.0}
      c0 <= eps -> {h1, h1}
      c1 <= eps -> {h0, h0}
      true -> {h0, h1}
    end
  end

  defp clamp_int(n, min, _max) when n < min, do: min
  defp clamp_int(n, _min, max) when n > max, do: max
  defp clamp_int(n, _min, _max), do: n

  defp clamp01(x) when x <= 0.0, do: 0.0
  defp clamp01(x) when x >= 1.0, do: 1.0
  defp clamp01(x), do: x * 1.0

  defp lerp_angle(a0, a1) do
    delta = angle_delta(a0, a1)
    fn t -> a0 + delta * t end
  end

  defp angle_delta(a0, a1) do
    two_pi = 2.0 * :math.pi()
    d = rem_float(a1 - a0, two_pi)
    if d > :math.pi(), do: d - two_pi, else: d
  end

  defp rem_float(x, m), do: x - m * :math.floor(x / m)

  # sRGB (0..255) -> OKLab (L,a,b)
  defp srgb255_to_oklab({r, g, b}) do
    {lr, lg, lb} =
      {r / 255.0, g / 255.0, b / 255.0}
      |> srgb_to_linear_rgb()

    l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
    m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
    s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb

    l_ = cbrt(l)
    m_ = cbrt(m)
    s_ = cbrt(s)

    l_ok = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a_ok = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    b_ok = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

    {l_ok, a_ok, b_ok}
  end

  # OKLab (L,a,b) -> sRGB (0..255 ints)
  defp oklab_to_srgb255({l_ok, a_ok, b_ok}) do
    l_ = l_ok + 0.3963377774 * a_ok + 0.2158037573 * b_ok
    m_ = l_ok - 0.1055613458 * a_ok - 0.0638541728 * b_ok
    s_ = l_ok - 0.0894841775 * a_ok - 1.2914855480 * b_ok

    l = cube(l_)
    m = cube(m_)
    s = cube(s_)

    lr = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    {sr, sg, sb} = linear_to_srgb_rgb({lr, lg, lb})

    {
      (clamp01(sr) * 255.0) |> round() |> clamp_int(0, 255),
      (clamp01(sg) * 255.0) |> round() |> clamp_int(0, 255),
      (clamp01(sb) * 255.0) |> round() |> clamp_int(0, 255)
    }
  end

  defp srgb255_to_oklch(rgb) do
    {l_ok, a_ok, b_ok} = srgb255_to_oklab(rgb)
    c = :math.sqrt(a_ok * a_ok + b_ok * b_ok)
    h = :math.atan2(b_ok, a_ok)
    {l_ok, c, h}
  end

  defp oklch_to_srgb255({l_ok, c, h}) do
    a_ok = c * :math.cos(h)
    b_ok = c * :math.sin(h)
    oklab_to_srgb255({l_ok, a_ok, b_ok})
  end

  defp srgb_to_linear_rgb({r, g, b}) do
    {srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)}
  end

  defp linear_to_srgb_rgb({r, g, b}) do
    {linear_to_srgb(r), linear_to_srgb(g), linear_to_srgb(b)}
  end

  defp srgb_to_linear(c), do: srgb_to_linear_one(clamp01(c))
  defp srgb_to_linear_one(c) when c <= 0.04045, do: c / 12.92
  defp srgb_to_linear_one(c), do: :math.pow((c + 0.055) / 1.055, 2.4)

  defp linear_to_srgb(c) when c <= 0.0, do: 0.0
  defp linear_to_srgb(c) when c <= 0.0031308, do: 12.92 * c
  defp linear_to_srgb(c), do: 1.055 * :math.pow(c, 1.0 / 2.4) - 0.055

  defp cbrt(x) when x < 0.0, do: -:math.pow(-x, 1.0 / 3.0)
  defp cbrt(x), do: :math.pow(x, 1.0 / 3.0)

  defp cube(x), do: x * x * x
end
