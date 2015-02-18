ET - Elixir Transducers
=======================

## Why Transducers?

Elixir already comes with Stream which seems to do the same sort of thing that transducers do, so why?

Transducers are simply a different model for doing the same sort of thing, but where Stream focuses on wrapping the collection in functions, transducers focus on wrapping the reducing function. It feels a bit more natural for me, at least, to think it terms of composing functions together and marrying them with the collection when one wants the calculation to be performed than coupling the collection with part of the reduction and then marrying it with the last bit of it.

## How does it look?

```elixir
stream =
     1..10000
  |> Stream.map(&some_nasty_transformation/1)
  |> Steram.filter(&filter_fun/1)
  |> Stream.take_while(&bool_check/1)

Enum.to_list(stream)
```

```elixir
r_fun =
     ET.Transducers.map(&some_nasty_transformation/1)
  |> ET.Transducers.filter(&filter_fun/1)
  |> ET.Transducers.take_while(&bool_check/1)
  |> ET.Reducers.list

ET.reduce(1..10000, r_fun)
```

## Status

Taking shape. Much of the standard library is implemented, although the focus has been more on learning how to compose transducers than performance.