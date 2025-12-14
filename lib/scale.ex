defprotocol Scale do
  @moduledoc """
  Protocol for mapping values from a *domain* to a *range*.

  Scales are typically passed around as structs and dispatched via this protocol:

      iex> s = Scale.Linear.new(domain: [0, 10], range: [0, 500])
      iex> Scale.map(s, 2)
      100.0
      iex> Scale.invert(s, 100)
      {:ok, 2.0}

  Not all scales support inversion. In that case `invert/2` returns
  `{:error, reason}`.
  """

  @spec domain(t) :: any
  def domain(scale)

  @spec range(t) :: any
  def range(scale)

  @spec map(t, any) :: any
  def map(scale, value)

  @type invert_error ::
          :not_invertible
          | :unknown_range_value
          | :invalid_domain
          | :invalid_range

  @spec invert(t, any) :: {:ok, any} | {:error, invert_error()}
  def invert(scale, value)
end
