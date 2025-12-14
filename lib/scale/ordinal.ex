defmodule Scale.Ordinal do
  @moduledoc """
  A discrete (categorical) scale that maps values by index lookup.

  This is the Elixir analogue of `d3.scaleOrdinal`, but intentionally keeps
  mapping pure: unknown domain values map to `unknown` (default: `nil`).

  If the domain is longer than the range, the range repeats (wrap-around),
  matching d3’s common behavior.

  ## Example (palette-like)

      iex> s = Scale.Ordinal.new(domain: ["a", "b", "c"], range: [{165, 42, 42}, {70, 130, 180}, {12, 34, 250}])
      iex> Scale.map(s, "a")
      {165, 42, 42}
      iex> Scale.map(s, "c")
      {12, 34, 250}
      iex> Scale.map(s, "missing")
      nil
      iex> Scale.invert(s, {165, 42, 42})
      {:error, :not_invertible}
  """

  @enforce_keys [:domain, :range, :index, :unknown]
  defstruct domain: [],
            range: [],
            index: %{},
            unknown: nil

  @type t :: %__MODULE__{
          domain: [any()],
          range: [any()],
          index: %{optional(any()) => non_neg_integer()},
          unknown: any()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    domain = Keyword.get(opts, :domain, [])
    range = Keyword.get(opts, :range, [])
    unknown = Keyword.get(opts, :unknown, nil)

    unless is_list(domain), do: raise(ArgumentError, "Scale.Ordinal domain must be a list, got: #{inspect(domain)}")
    unless is_list(range), do: raise(ArgumentError, "Scale.Ordinal range must be a list, got: #{inspect(range)}")

    %__MODULE__{
      domain: domain,
      range: range,
      index: build_index(domain),
      unknown: unknown
    }
  end

  @spec set_domain(t(), [any()]) :: t()
  def set_domain(%__MODULE__{} = scale, domain) when is_list(domain) do
    %{scale | domain: domain, index: build_index(domain)}
  end

  defp build_index(domain) do
    domain
    |> Enum.with_index()
    |> Map.new(fn {value, idx} -> {value, idx} end)
  end
end

defimpl Scale, for: Scale.Ordinal do
  def domain(%Scale.Ordinal{domain: domain}), do: domain
  def range(%Scale.Ordinal{range: range}), do: range

  def map(%Scale.Ordinal{index: index, range: range, unknown: unknown}, value) do
    case Map.fetch(index, value) do
      {:ok, idx} ->
        case range do
          [] -> unknown
          _ -> Enum.at(range, rem(idx, length(range)))
        end

      :error ->
        unknown
    end
  end

  def invert(%Scale.Ordinal{}, _value), do: {:error, :not_invertible}
end
