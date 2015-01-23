defmodule ET do

  @moduledoc """
  Provides general purpose functions and types which don't really fit in other modules.
  """

  @typedoc """
  A message to be sent to a reducer.

  :init is always called before any elements are passed.
  {:cont, element, state} is called for every element while the reduction continues.
  {:fin, state} is called to finalize anything and get the value to return.

  """

  @type signal_message :: :init | {:cont, term, list} | {:fin, list}

  @typedoc """
  A message received from a reducer.

  {:cont, state} indicates the reducer wants a new element.
  {:halt, state} indicates the reducer wants to finish the reduction.
  {:fin, result} indicates that the reducer has finished and here is the result.

  """
  
  @type return_message :: {:cont, list} | {:halt, list} | {:fin, list}

  @typedoc """
  A function which transforms signal_messages into return_messages. See ET.Reducers
  for a detailed explanation.

  """

  @type reducer :: (signal_message -> return_message)

  @doc """
  Applies a reducer to a transducible data structure.

  Reduce applies a reducer by first sending the :init signal to it to generate
  the initial state list. It then pulls elements from the transducible one at
  a time until the transducible sends :done or the reducer returns
  {:halt, state}. It then sends a {:fin, state} signal to complete the reduce.

    iex> ET.reduce(1..3, ET.Reducers.list())
    [1,2,3]

  """

  @spec reduce(Transducible.t, reducer) :: term
  def reduce(coll, reducer) do
    do_reduce(coll, reducer.(:init), reducer)
  end

  @spec do_reduce(Transducible.t, {:cont | :halt | :done, list}, reducer) :: term
  defp do_reduce(coll, {:cont, state}, reducer) do
    {signal, collection} = reduce_step(coll, state, reducer)
    do_reduce(collection, signal, reducer)
  end
  defp do_reduce(_coll, {:done, state}, reducer), do: finish_reduce(state, reducer)
  defp do_reduce(_coll, {:halt, state}, reducer), do: finish_reduce(state, reducer)

  @spec finish_reduce(list, reducer) :: term
  defp finish_reduce(state, reducer) do
    {:fin, result} = reducer.({:fin, state})
    result
  end

  @doc """
  A helper function for performing a single :cont step of the reduce operation.

  """
  
  @spec reduce_step(Transducible.t, list, reducer) :: return_message | {:done, list}
  def reduce_step(collection, state, reducer) do
    case Transducible.next(collection) do
      {elem, rem} -> {reducer.({:cont, elem, state}), rem}
      :done       -> {{:done, state}, collection}
    end
  end
end
