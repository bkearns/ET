defmodule ET.Transducers do
  @moduledoc """
  Provides composable transducer functions.

  Transducers are anonymous functions which take a reducer and return a new reducer
  with the new functionality wrapped around it. Transducers end up having to pass
  signals up and down, transforming, filtering, or doing other fun stuff along the way.

  Transducers should know as little as possible about what is above and below them in
  order to maintain composability.

  ET.Transducer provides a struct to wrap your transducer functions.

  Named transducer functions should optionally take an %ET.Transducer{} struct as their
  first argument to aid in pipelining (all of the transducers in this library do so).

  """
  
  import ET.Transducer

  @doc """
  A transducer which applies the supplied function and passes the result to the reducer.

    iex> add_one = ET.Transducers.map(&(&1+1) |> ET.Reducers.list()
    iex> ET.reduce(1..3, add_one)
    [2,3,4]

  """
  
  @spec map(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec map((term -> term)) :: ET.Transducer.t
  def map(%ET.Transducer{} = trans, fun), do: combine(trans, map(fun))
  def map(fun) do
    %ET.Transducer{elements:
      [fn reducer ->
         fn
           :init                 -> reducer.(:init)
           {:cont, input, state} -> reducer.({:cont, fun.(input), state})
           {:fin, state}         -> reducer.({:fin, state})
         end
       end]}
  end

  @doc """
  A transducer which limits the number of elements processed.

  This transducer will halt on the element *after* the last one it sends to
  its reducer.

    iex> take_two = ET.Transducers.take(2) |> ET.Reducers.list
    iex> ET.reduce(1..3, take_two)
    [1,2]

  """
  
  @spec take(ET.Transducer.t , non_neg_integer) :: ET.Transducer.t
  @spec take(non_neg_integer) :: ET.Transducer.t
  def take(%ET.Transducer{} = trans, num), do: combine(trans, take(num))
  def take(num) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state(num)
         {:cont, _elem, [0 | _] = state} ->
           {:halt, state}
         {:cont, elem, [my_state | state]} ->
           reducer.({:cont, elem, state}) |> prepend_state(my_state-1)
         {:fin, [_|state]} -> reducer.({:fin, state})
      end
    end]}
  end

  @doc """
  A transducers which takes several transducers and interleaves their
  contents.

  Zip sends the first element of each transducible as soon as it receives it,
  but all remaining elements are cached until a signal to finish is received
  at which point it recurses over the remaining elements. If it ever receives
  a signal to halt from below, it clears its cache.

    iex> ET.reduce([1..4, ["a", "b"]], ET.Transducers.zip |> ET.Reducers.list)
    [1, "a", 2, "b", 3, 4]

    iex> zip_then_take_three = ET.Transducers.zip |> ET.Transducers.take(3) |> ET.Reducers.list
    iex> ET.reduce([1..4, ["a", "b"]], zip_then_take_three)
    [1, "a", 2]

  """
  
  @spec zip(ET.Transducer.t) :: ET.Transducer.t
  @spec zip() :: ET.Transducer.t
  def zip(%ET.Transducer{} = trans), do: combine(trans, zip())
  def zip() do
    %ET.Transducer{elements:
      [fn reducer ->
        fn
          :init -> reducer.(:init) |> prepend_state([])
          {:cont, input, [transducibles | rem_state]} ->
            do_first_zip(ET.reduce_step(input, rem_state, reducer), transducibles)
          {:fin, [transducibles | rem_state]} ->
            do_final_zip([], transducibles, {:cont, rem_state}, reducer)
        end
      end]}
  end

  defp do_first_zip({{:done, state}, _coll}, my_state), do: {:cont, [my_state | state]}
  defp do_first_zip({{:halt, state}, _coll}, my_state), do: prepend_state({:halt, state}, [])
  defp do_first_zip({{:cont, state},  coll}, my_state), do: prepend_state({:cont, state}, [coll | my_state])

  defp do_final_zip( _,  _, {:halt, state}, reducer), do: reducer.({:fin, state})
  defp do_final_zip([], [], {:cont, state}, reducer), do: reducer.({:fin, state})
  defp do_final_zip(ts, [_done_trans | rem], {:done, state}, reducer) do
    do_final_zip(ts, rem, {:cont, state}, reducer)
  end
  defp do_final_zip([], t_acc, signal, reducer), do: do_final_zip(:lists.reverse(t_acc), [], signal, reducer)
  defp do_final_zip([transducible | rem], t_acc, {:cont, state}, reducer) do
    {signal, new_t} = ET.reduce_step(transducible, state, reducer)
    do_final_zip(rem, [new_t | t_acc], signal, reducer)
  end
end
