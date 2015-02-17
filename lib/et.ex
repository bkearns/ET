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
    {_coll, {_, {_sig, r_state}}} = reduce_elements(coll, {r_fun, r_fun.(:init)})
    r_fun.({:done, r_state})
  end


  @doc """
  A helper function for performing the :cont recursion over a transducible into
  a reducer with an already generated state.

  """

  def reduce_elements(:empty, reducer), do: {:empty, reducer}
  def reduce_elements(coll, {_, {:cont, _}} = reducer) do
    {collection, reducer} = reduce_step(coll, reducer)
    reduce_elements(collection, reducer)
  end
  def reduce_elements(coll, reducer), do: {coll, reducer}

  @doc """
  A helper function for performing a single :cont step of the reduce operation.

  It returns a tuple with a continuation and a reducer. If the continuation
  is :done, the tuple continuation will be :empty.

  """

  def reduce_step(collection, {r_fun, {:cont, r_state}}) do
    case Transducible.next(collection) do
      {elem, rem} ->
        {sig, state} = r_fun.({:cont, r_state, elem})
        {rem, {r_fun, {sig, state}}}
      :done -> {:empty, {r_fun, {:cont, r_state}}}
    end
  end
end
