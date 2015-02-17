defmodule ET do

  @moduledoc """
  Provides general purpose functions and types which don't really fit in other
  modules.
  """

  @doc """
  Applies a reducing function to a transducible data structure.

  Reduce applies a reducing function by first sending the :init signal to it to
  generate the initial state. It then pulls elements from the transducible one
  at a time until the transducible sends :done or the reducing function returns
  {:done, state}. It then sends a {:done, state} signal to complete the
  reduction.

    iex> ET.reduce(1..3, ET.Reducers.list())
    [1,2,3]

  """

  def reduce(coll, r_fun) do
    {_signal, state, _coll} = reduce_elements(coll, r_fun.(:init), r_fun)
    r_fun.({:done, state})
  end


  @doc """
  A helper function for performing the :cont recursion over a transducible into
  a reducer with an already generated state.

  """

  def reduce_elements(coll, {:cont, state}, r_fun) do
    {signal, state, collection} = reduce_step(coll, state, r_fun)
    reduce_elements(collection, {signal, state}, r_fun)
  end
  def reduce_elements(coll, {signal, state}, r_fun) do
    {signal, state, coll}
  end


  @doc """
  A helper function for performing a single :cont step of the reduce operation.

  It returns a tuple in the form of {{signal, reducer_state}, collection} with
  the normal reducer signals with the addition of :done, which will be returned
  when the collection doesn't provide a new element and thus the reducer is not
  called.

  """

  def reduce_step(collection, state, r_fun) do
    case Transducible.next(collection) do
      {elem, rem} ->
        {sig, state} = r_fun.({:cont, state, elem})
        {sig, state, rem}
      :done -> {:empty, state, collection}
    end
  end
end
