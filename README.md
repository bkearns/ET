ET - Elixir Transducers
=======================

## Why Transducers?

Standard enumerators get us very far already, why a different model? Well, let's say you have something like this:

```elixir
big_list
|> Enum.map( &some_expensive_transformation/1 )
|> Enum.take_while( &bool_test/1 )
```

You just did a big, expensive transformation against a big list and you might only end up keeping a hand-full of them.

Transducers solve this by creating Stream-like composable functions, but with the added benefit of managing their own flow-control. Transducer elements also don't care what sort of collection it is coming from or what sort it is going to.

## How does it look?

```elixir
reducer =
     ET.Transducers.map( &some_expensive_transformation/1 )
  |> ET.Transducers.take_while( &bool_test/1 )
  |> ET.Reducers.list
ET.reduce( big_list, reducer )
```

## Status

Taking shape. Getting ready to start churning out standard enumerable elements in transducer form. Still thinking on if/how the reduce function should be able to change the default arguments.