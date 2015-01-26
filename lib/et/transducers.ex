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

  def chunk(size), do: chunk(size, size, ET.Reducers.list)
  def chunk(%ET.Transducer{} = trans, size), do: combine(trans, chunk(size))
  def chunk(size, step) when is_integer(step), do: chunk(size, step, ET.Reducers.list)
  def chunk(size, inner_reducer) when is_function(inner_reducer, 1) do
    chunk(size, size, inner_reducer)
  end
  def chunk(%ET.Transducer{} = trans, this, that), do: combine(trans, chunk(this, that))
  def chunk(size, step, inner_reducer) do
    inner_reducer =
      ET.Transducers.take(size)
      |> ET.Transducers.ensure(size)
      |> ET.Transducer.compose(inner_reducer)
    
    %ET.Transducer{elements: [fn reducer ->
      fn signal ->
        do_chunk(signal, step, inner_reducer, reducer)
      end
    end]}
  end

  defp do_chunk(:init, _step, _inner_reducer, outer_reducer) do
    outer_reducer.(:init) |> prepend_state({0, []})
  end
  defp do_chunk({:cont, elem, [{0, chunks} | rem_state]}, step, inner_reducer, outer_reducer) do
    {:cont, state} = inner_reducer.(:init)
    do_chunk({:cont, elem, [{step, [state | chunks]} | rem_state]},
             step, inner_reducer, outer_reducer)
  end
  defp do_chunk({:cont, elem, [{countdown, chunks} | rem_state]}, _step, inner_reducer, outer_reducer) do
    {cont, halt} = apply_element_to_states(:lists.reverse(chunks), elem, inner_reducer)
    fin = finish_states(:lists.reverse(halt), inner_reducer)
    {signal, new_state} = continue_elements(fin, {:cont, rem_state}, outer_reducer)
    {signal, [{countdown-1, cont} | new_state]}
  end
  defp do_chunk({:fin, [_my_state | rem_state]}, _step, _inner_reducer, outer_reducer) do
    outer_reducer.({:fin, rem_state})
  end

  defp apply_element_to_states(states, elem, reducer, acc \\ {[],[]})
  defp apply_element_to_states([], _elem, _reducer, {cont, halt}), do: {cont, halt}
  defp apply_element_to_states([state | rem_states], elem, reducer, {cont, halt}) do
    result =
    case reducer.({:cont, elem, state}) do
      {:cont, new_state} -> {[new_state | cont], halt}
      {_, new_state}     -> {cont, [new_state | halt]}
    end
    apply_element_to_states(rem_states, elem, reducer, result)
  end

  defp finish_states(states, reducer, acc \\ [])
  defp finish_states([], _reducer, acc), do: :lists.reverse(acc)
  defp finish_states([state | rem_states], reducer, acc) do
    {:fin, result} = reducer.({:fin, state})
    finish_states(rem_states, reducer, [result | acc])
  end

  defp continue_elements([], signal, _reducer), do: signal
  defp continue_elements(_, {:halt, state}, _reducer), do: {:halt, state}
  defp continue_elements([elem | elements], {:cont, state}, reducer) do
    continue_elements(elements, reducer.({:cont, elem, state}), reducer)
  end
  
  @doc """
  A transducer which will not relay :halt signals until it has recieved a specified
  number of elements. Elements received after a :halt signal is recieved are not
  passed to the reducer. It has no special effect if a :fin signal is received
  before a :halt.

  """
  
  @spec ensure(ET.Transducer.t, non_neg_integer) :: ET.Transducer.t
  @spec ensure(non_neg_integer) :: ET.Transducer.t
  def ensure(%ET.Transducer{} = trans, n), do: combine(trans, ensure(n))
  def ensure(n) do
    %ET.Transducer{elements: [fn reducer -> &(do_ensure(&1, reducer, n)) end]}
  end

  defp do_ensure(:init, reducer, n), do: reducer.(:init) |> prepend_state({:cont, n})
  defp do_ensure({:cont, elem, [{:cont, n} | rem_state]}, reducer, _n) when n < 2 do
    reducer.({:cont, elem, rem_state}) |> prepend_state({:cont, n})
  end
  defp do_ensure({:cont, elem, [{:cont, n} | rem_state]}, reducer, _n) do
    case reducer.({:cont, elem, rem_state}) do
      {:halt, state} -> {:cont, [{:halt, n-1} | state]}
      {:cont, state} -> {:cont, [{:cont, n-1} | state]}
    end
  end
   defp do_ensure({:cont, _elem, [{:halt, n} | rem_state]}, _reducer, _n) when n < 2 do
     {:halt, [{:halt, n} | rem_state]}
  end
  defp do_ensure({:cont, _elem, [{:halt, n} | rem_state]}, _reducer, _n) do
    {:cont, [{:halt, n-1} | rem_state]}
  end
  defp do_ensure({:fin, [_my_state | rem_state]}, reducer, _n) do
    reducer.({:fin, rem_state})
  end
  
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
         {:cont, elem, [1 | rem_state]} ->
           {_signal, state} = reducer.({:cont, elem, rem_state})
           {:halt, [0 | state]}
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
  defp do_first_zip({{:halt, state}, _coll}, _my_state), do: prepend_state({:halt, state}, [])
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
