ET - Elixir Transducers
=======================

## Why Transducers?

Elixir already comes with Stream which seems to do the same sort of thing that transducers do, so why?

Transducers are simply a different model for doing the same sort of thing, but where Stream focuses on wrapping the collection in functions, transducers focus on wrapping the reducing function. It feels a bit more natural for me, at least, to think it terms of composing functions together and marrying them with the collection when one wants the calculation to be performed than coupling the collection with part of the reduction and then marrying it with the last bit of it.

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

Also, these transducers are implemented in more generic ways to allow for deeper composability.

```elixir
r_fun =
     ET.Transducers.group_by(&( rem(&1, 3) ))
  |> ET.Reducers.map

ET.reduce(1..7, r_fun)  #> %{0 => [3, 6], 1 => [1, 4, 7], 2 => [2, 5]}
```

```elixir
all_lt_five? = ET.Reducers.all?(&(&1<5))

r_fun =
     ET.Transducers.group_by(&( rem(&1, 3) ),
                             ET.Reducers.count,
                             %{0 => all_lt_five?})
  |> ET.Reducers.map

ET.reduce(1..6, r_fun)  #> %{0 => false, 1 => 3, 2 => 2}
```

## Status

Taking shape. Much of the standard library is implemented, although the focus has been more on learning how to compose transducers than performance.
