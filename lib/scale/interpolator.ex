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

  defp clamp_int(n, min, _max) when n < min, do: min
  defp clamp_int(n, _min, max) when n > max, do: max
  defp clamp_int(n, _min, _max), do: n
end
