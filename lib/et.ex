defmodule ET do

  @moduledoc """
  Provides general purpose functions and types which don't really fit in other
  modules.
  """

  def next(collection) when is_function(collection, 1) do
    collection.({:cont, nil})
  end
  def next(collection) do
    suspend_fun = fn elem, _ -> {:suspend, elem} end
    Enumerable.reduce(collection, {:cont, nil}, suspend_fun)
  end


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
    {_, r_state} = Enumerable.reduce(coll, r_fun.(nil, :init), r_fun)
    r_fun.(r_state, :fin)
  end
end
