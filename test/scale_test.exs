defmodule ScaleTest do
  use ExUnit.Case

  doctest Scale
  doctest Scale.Linear
  doctest Scale.Interpolator
  doctest Scale.Ordinal
  doctest Scale.Quantize

  test "linear maps domain to pixel range" do
    s = Scale.Linear.new(domain: [0, 10], range: [0, 800])

    assert Scale.map(s, 0) == 0.0
    assert Scale.map(s, 10) == 800.0
    assert_in_delta Scale.map(s, 2.5), 200.0, 1.0e-12

    assert Scale.invert(s, 0) == {:ok, 0.0}
    assert Scale.invert(s, 800) == {:ok, 10.0}
    assert_in_delta elem(Scale.invert(s, 200.0), 1), 2.5, 1.0e-12
  end

  test "linear clamp constrains mapping and inversion" do
    s = Scale.Linear.new(domain: [0, 10], range: [0, 800], clamp: true)

    assert Scale.map(s, -1) == 0.0
    assert Scale.map(s, 11) == 800.0

    assert Scale.invert(s, -100) == {:ok, 0.0}
    assert Scale.invert(s, 900) == {:ok, 10.0}
  end

  test "linear can interpolate rgb tuples but cannot invert them" do
    s =
      Scale.Linear.new(
        domain: [0, 1],
        range: [{255, 0, 0}, {0, 0, 255}],
        interpolate: &Scale.Interpolator.rgb/2
      )

    assert Scale.map(s, 0.5) == {128, 0, 128}
    assert Scale.invert(s, {128, 0, 128}) == {:error, :invalid_range}
  end

  # Taken from https://d3js.org/d3-scale/linear#_linear
  # color(20); // "rgb(154, 52, 57)"
  # color(50); // "rgb(123, 81, 103)"
  test "linear can interpolate between brown and steelblue" do
    s =
      Scale.Linear.new(
        domain: [10, 100],
        range: [{165, 42, 42}, {70, 130, 180}],
        interpolate: &Scale.Interpolator.rgb/2
      )

    assert Scale.map(s, 20) == {154, 52, 57}
    assert Scale.map(s, 50) == {123, 81, 103}
    assert Scale.invert(s, {128, 0, 128}) == {:error, :invalid_range}
  end

  test "clamp clamps the value within the scales range" do
    s2 =
      Scale.Linear.new(
        domain: [10, 130],
        range: [0, 960],
        clamp: false
      )

    assert Scale.map(s2, -10) == -160

    s =
      Scale.Linear.new(
        domain: [10, 130],
        range: [0, 960],
        clamp: true
      )

    assert Scale.map(s, 140) == 960
    assert Scale.map(s, -10) == 0
  end

  test "ordinal maps domain values to range values" do
    s =
      Scale.Ordinal.new(
        domain: ["a", "b", "c"],
        range: [{165, 42, 42}, {70, 130, 180}, {12, 34, 250}]
      )

    assert Scale.map(s, "a") == {165, 42, 42}
    assert Scale.map(s, "c") == {12, 34, 250}
    assert Scale.map(s, "missing") == nil
    assert Scale.invert(s, {165, 42, 42}) == {:error, :not_invertible}
  end

  test "ordinal wraps the range when domain is longer" do
    s = Scale.Ordinal.new(domain: [:a, :b, :c], range: [1, 2])
    assert Scale.map(s, :a) == 1
    assert Scale.map(s, :b) == 2
    assert Scale.map(s, :c) == 1
  end

  test "quantize maps continuous domain to discrete range buckets" do
    s = Scale.Quantize.new(domain: [0, 100], range: [:a, :b, :c, :d, :e])

    assert Scale.map(s, -10) == :a
    assert Scale.map(s, 0) == :a
    assert Scale.map(s, 19.999) == :a
    assert Scale.map(s, 20) == :b
    assert Scale.map(s, 40) == :c
    assert Scale.map(s, 60) == :d
    assert Scale.map(s, 80) == :e
    assert Scale.map(s, 100) == :e
    assert Scale.map(s, 110) == :e
  end

  test "quantize invert returns bucket extents" do
    s = Scale.Quantize.new(domain: [0, 100], range: [:a, :b, :c, :d, :e])

    assert Scale.invert(s, :a) == {:ok, {0.0, 20.0}}
    assert Scale.invert(s, :c) == {:ok, {40.0, 60.0}}
    assert Scale.invert(s, :e) == {:ok, {80.0, 100.0}}
    assert Scale.invert(s, :missing) == {:error, :unknown_range_value}
  end
end
