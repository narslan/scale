# Repository Guidelines

## Project Structure & Module Organization

- `lib/` contains the library code.
  - `lib/scale.ex` defines the `Scale` protocol (`domain/1`, `range/1`, `map/2`, `invert/2`).
  - `lib/scale/*.ex` contains concrete implementations: `Scale.Linear`, `Scale.Ordinal`, `Scale.Quantize`, `Scale.Band`, plus helpers in `Scale.Interpolator`.
- `test/` contains ExUnit tests and doctests (`test/test_helper.exs`, `test/scale_test.exs`).
- Generated/ignored directories: `_build/`, `deps/`, `doc/`, `cover/`, `tmp/`.

## Build, Test, and Development Commands

- `mix deps.get` fetch dependencies.
- `mix test` runs the test suite (includes doctests).
- `mix test --cover` runs tests and writes coverage output to `cover/`.
- `mix format` formats code using `.formatter.exs`.
- `mix credo` runs static analysis (dev/test dependency).
- `mix docs` generates documentation into `doc/` (dev dependency).

Note: `mix.exs` currently targets Elixir `~> 1.20-dev`; use a compatible Elixir version when contributing.

## Coding Style & Naming Conventions

- Use `mix format` before pushing; follow standard Elixir style (2-space indentation, no tabs).
- Keep module/file alignment: `Scale.Foo` lives in `lib/scale/foo.ex`.
- Prefer small, documented public APIs with short `@doc` examples (`iex>`), especially for new scales/interpolators.

## Testing Guidelines

- Use ExUnit; add/extend doctests for public modules and add explicit tests for edge cases (e.g., clamping, invalid inputs, non-invertible scales).
- Name test files `*_test.exs`; use `assert_in_delta` for floating-point comparisons.

## Commit & Pull Request Guidelines

- Follow the existing commit subject style (lightweight Conventional Commits): `feat: ...`, `doc: ...`, and when applicable `fix: ...`, `test: ...`, `refactor: ...`.
- PRs should include a short description, motivation/issue link (if any), and commands run (typically `mix test` and `mix format`; add `mix credo` when changing behavior).
