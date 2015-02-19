defmodule ET.Reducers do
  @moduledoc """
  ET.Reducers are a special sort of reduction function which takes and returns
  control-flow information.

  Reducers are expected to accept the following commands:

    _, :init -> Sent once before other signals, this is a good opportunity to
                set initial state.
    element, state -> This message is sent for each element as long as the
                      reduction is continuing.
    state, :fin -> Called as long as there is not an exception. This is an
                   opportunity to close anything that needs closing and
                   indicates that the result should be returned.

  The state object is shared among any transducers and the reducer and is a
  list. A stateful transducer or reducer is allowed one element on this list and
  must remove it before sending a message to the reducer below it so that the
  next stateful function's state is the new head.

  :init and continue can return either:

    {:cont, state} -> Indicates that the reducer is ready and waiting for a new
                      element.
    {:halt, state} -> Indicates that no more elements should be sent and a :fin
                      signal should come next to finish the reduction.

  When a reducer takes the :fin command, it simply returns the result of the
  reduction

  This module contains base reducers which might become wrapped with layers of
  transducers. These reducers are intended to build the final result of a
  reduction.

  Named reducer functions should optionally take an %ET.Transducer{} as a first
  argument to aid in pipelining and all of the functions in this module do so.
  """

  import ET.Transducer, only: [compose: 2]

  @doc """
  A reducer which returns true if the function returns true for every element
  received and short-circuits false if it ever returns false.

    iex> ET.reduce([1,2,3], ET.Reducers.all?(&(&1<4)))
    true

    iex> ET.reduce([1,2,3,4], ET.Reducers.all?(&(&1<4)))
    false

  """

  def all?(%ET.Transducer{} = trans, fun), do: compose(trans, all?(fun))
  def all?(%ET.Transducer{} = trans), do: all?(trans, fn x -> x end)
  def all?(fun) do
    fn
      _, :init -> {:cont, [true]}
      [result], :fin -> result
      elem, [_] ->
        if fun.(elem) do
          {:cont, [true]}
        else
          {:halt, [false]}
        end
    end
  end
  def all?(), do: all?(fn x -> x end)

  @doc """
  A reducer which returns false if the function returns false for every element
  received and short-circuits true if it ever returns true.

    iex> ET.reduce([1,2,3], ET.Reducers.any?(&(&1<2)))
    true

    iex> ET.reduce([2,3,4], ET.Reducers.any?(&(&1<2)))
    false

  """

  def any?(%ET.Transducer{} = trans, fun), do: compose(trans, any?(fun))
  def any?(%ET.Transducer{} = trans), do: any?(trans, fn x -> x end)
  def any?(fun) do
    fn
      _, :init -> {:cont, [false]}
      [result], :fin -> result
      elem, [_] ->
        if fun.(elem) do
          {:halt, [true]}
        else
          {:cont, [false]}
        end
    end
  end
  def any?(), do: any?(fn x -> x end)


  @doc """
  A reducer which takes inputs and concats them into a single binary.

  """

  def binary() do
    fn
      _, :init     -> {:cont, [""]}
      [acc], :fin -> acc
      elem, [acc]  -> {:cont, [acc <> to_string(elem)]}
    end
  end
  def binary(%ET.Transducer{} = trans), do: compose(trans, binary)


  @doc """
  A reducer which counts the number of items recieved.

    iex> ET.reduce(1..3, ET.Reducers.count)
    3

  """

  def count(%ET.Transducer{} = trans), do: compose(trans, count())
  def count() do
    fn _, :init      -> {:cont, [0]}
       [acc], :fin -> acc
       _elem, [acc] -> {:cont, [acc+1]}
    end
  end


  @doc """
  A reducer which uses the Collectable protocol to build a new collection from
  an existing collection.

  """

  def into(collectable) do
    fn
      _, :init -> {:cont, [Collectable.into(collectable)]}
      [{acc, c_fun}], :fin -> c_fun.(acc, :done)
      elem, [{acc, c_fun}] ->
        {:cont, [{c_fun.(acc, {:cont, elem}), c_fun}]}
    end
  end
  def into(%ET.Transducer{} = trans, coll) do
    compose(trans, into(coll))
  end


  @doc """
  A reducer which returns a list of items received in the same order.

    iex> ET.reduce(1..3, ET.Reducers.list)
    [1,2,3]
  """

  def list(%ET.Transducer{} = trans), do: compose(trans, list())
  def list do
    fn
      _, :init     -> { :cont, [[]] }
      [acc], :fin -> :lists.reverse(acc)
      elem, [acc]  -> { :cont, [[elem | acc]] }
    end
  end


  @doc """
  A reducer which returns the last element received or term (default nil).

  """

  def last(), do: last(nil)
  def last(%ET.Transducer{} = trans), do: compose(trans, last)
  def last(term) do
    fn
      _, :init       -> {:cont, [term]}
      [result], :fin -> result
      elem, [_]      -> {:cont, [elem]}
    end
  end
  def last(%ET.Transducer{} = trans, term), do: compose(trans, last(term))


  @doc """
  A reducer which accepts tuples in the form of {key, value} and returns
  a Map.

  If fun/2 is provided, it should be of the form:
  (new_value, stored_value -> new_stored_value)

  """

  def map() do
    fn
      _, :init -> {:cont, [%{}]}
      [acc], :fin -> acc
      {key, value}, [acc] ->
        {:cont, [Dict.put(acc, key, value)]}
    end
  end
  def map(%ET.Transducer{} = trans), do: compose(trans, map)
  def map(fun) do
    fn
      _, :init -> {:cont, [%{}]}
      [acc], :fin -> acc
      {key, value}, [acc] ->
        {:cont, [Dict.update(acc, key, value, &(fun.(&1,value)))]}
    end
  end
  def map(%ET.Transducer{} = trans, fun), do: compose(trans, map(fun))


  @doc """
  A reducer which returns the largest element or nil if no elements are
  received.

  """

  def max() do
    max_by(&(&1))
  end
  def max(%ET.Transducer{} = trans), do: compose(trans, max)


  @doc """
  A reducer which returns the element for which fun.(element) is the largest or
  nil if no elements are received.

  """

  def max_by(fun) do
    ET.Logic.structure(fun)
    |> ET.Logic.unfold(nil, max_compare_fun)
    |> ET.Logic.last_by
    |> ET.Logic.destructure(2)
    |> ET.Reducers.last
  end
  def max_by(%ET.Transducer{} = trans, fun), do: compose(trans, max_by(fun))

  defp max_compare_fun do
    fn
      e, nil -> {true, e}
      {_,c1} = elem, {_,c2} when c1 > c2 -> {true, elem}
      _, acc -> {false, acc}
    end
  end


  @doc """
  A reducer which returns the smallest element or nil if no elements are
  received.

  """

  def min() do
    min_by(&(&1))
  end
  def min(%ET.Transducer{} = trans), do: compose(trans, min)


  @doc """
  A reducers which returns the element for which fun.(element) is the smallest
  or nil if no elements are received.

  """

  def min_by(fun) do
    ET.Logic.structure(fun)
    |> ET.Logic.unfold(nil, min_compare_fun)
    |> ET.Logic.last_by
    |> ET.Logic.destructure(2)
    |> ET.Reducers.last
  end
  def min_by(%ET.Transducer{} = trans, fun), do: compose(trans, min_by(fun))

  defp min_compare_fun do
    fn
      e, nil -> {true, e}
      {_,c1} = elem, {_,c2} when c1 < c2 -> {true, elem}
      _, acc -> {false, acc}
    end
  end

  @doc """
  A reducer which returns a fixed value regardless of what it receives.
  The default is :ok.

  """

  def static(), do: static(:ok)
  def static(%ET.Transducer{} = trans), do: compose(trans, static)
  def static(t) do
    fn _, :init  -> {:cont, []}
       [], :fin -> t
       _elem, [] -> {:cont, []}
    end
  end
  def static(%ET.Transducer{} = trans, t), do: compose(trans, static(t))
end
