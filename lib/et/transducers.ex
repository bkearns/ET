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
  A transducer which takes elements and emits chunks of size elements. These chunks default
  to ET.Reducers.list(), but an alternate reducer may be substituted. Elements in each chunk
  are cached until size elements are received and then all are resolved immediately and 
  the result is handed to the main reducer.

  Chunking begins with the first element and by default a new chunk is created every size
  elements, but step can be defined to start chunks more or less frequently.

  If padding is not defined, then incomplete chunks are discarded. If it is defined, then
  elements are applied to incomplete chunks until either all chunks are complete or 
  padding is done and incomplete chunks are processed.

    iex> chunker = ET.Transducers.chunk(2) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [3,4]]

    iex> chunker = ET.Transducers.chunk(2, 1) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [2,3], [3,4], [4,5]]

    iex> chunker = ET.Transducers.chunk(2, [:a,:b,:c]) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [3,4], [5,:a]]

    iex> chunker = ET.Transducers.chunk(2, []) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [3,4], [5]]

  """

  # TODO spec definition for chunk
  def chunk(size), do: chunk(size, size, ET.Reducers.list(), nil)
  def chunk(%ET.Transducer{} = trans, size), do: compose(trans, chunk(size))
  def chunk(size, step) when is_integer(step), do: chunk(size, step, ET.Reducers.list(), nil)
  def chunk(size, inner_reducer) when is_function(inner_reducer, 1) do
    chunk(size, size, inner_reducer, nil)
  end
  def chunk(size, padding), do: chunk(size, size, ET.Reducers.list(), padding)
  def chunk(%ET.Transducer{} = trans, this, that), do: compose(trans, chunk(this, that))
  def chunk(size, step, inner_reducer), do: chunk(size, step, inner_reducer, nil)
  def chunk(%ET.Transducer{} = trans, this, that, other) do
    compose(trans, chunk(this, that, other))
  end
  def chunk(size, step, inner_reducer, padding) do
    %ET.Transducer{elements: [fn reducer ->
      inner_reducer =
        ET.Transducers.cache(size, !padding)
        |> ET.Transducers.take(size)
        |> ET.Transducer.compose(inner_reducer)

      fn signal ->
        do_chunk(signal, step, inner_reducer, reducer, padding)
      end
    end]}
  end
  def chunk(%ET.Transducer{} = trans, this, that, other, another) do
    compose(trans, chunk(this, that, other, another))
  end

  defp do_chunk(:init, _step, _inner_reducer, reducer, _padding) do
    {r_signal, state} = reducer.(:init)
    {r_signal, [{0, [], r_signal} | state]}
  end
  defp do_chunk({:cont, elem, [{0, chunks, r_signal} | rem_state]}, step, inner_reducer, reducer, padding) do
    do_chunk({:cont, elem, [{step, [inner_reducer.(:init) | chunks], r_signal} | rem_state]}, step, inner_reducer, reducer, padding)
  end
  defp do_chunk({:cont, elem, [{countdown, chunks, r_signal} | rem_state]}, _step, inner_reducer, reducer, _padding) do
    {{signal, state}, new_chunks} = apply_element(chunks, elem, inner_reducer, reducer, {r_signal, rem_state})
    {signal, [{countdown-1, new_chunks, signal} | state]}
  end
  defp do_chunk({:fin, [{_, chunks, _r_signal} | rem_state]}, _step, inner_reducer, reducer, nil) do
    finish_chunks(chunks, inner_reducer)
    reducer.({:fin, rem_state})
  end
  defp do_chunk({:fin, [{countdown, chunks, r_signal} | rem_state]}, step, inner_reducer, reducer, padding) do
    {{r_signal, rem_state}, chunks} =
      apply_padding(chunks, Transducible.next(padding), inner_reducer, reducer, {r_signal, rem_state})
    do_chunk({:fin, [{countdown, chunks, r_signal} | rem_state]}, step, inner_reducer, reducer, nil)
  end

  defp apply_element(chunks, elem, inner_reducer, halt_reducer, halt_signal) do
    apply_element(:lists.reverse(chunks), elem, inner_reducer, halt_reducer, halt_signal, [])
  end
  defp apply_element([], _, _, _, halt_signal, acc) do
    {halt_signal, acc}
  end
  defp apply_element([chunk | chunks], elem, inner_reducer, halt_reducer, {:halt, state}, acc) do
    apply_element(chunks, elem, inner_reducer, halt_reducer, {:halt, state}, [chunk | acc])
  end
  defp apply_element([signal | chunks], elem, inner_reducer, halt_reducer, {:cont, halt_state}, acc) do
    case ET.reduce_elements([elem], signal, inner_reducer) do
      {:done, state} ->
        apply_element(chunks, elem, inner_reducer, halt_reducer, {:cont, halt_state}, [{:cont, state} | acc])
      {:halt, state} ->
        h_elem = ET.finish_reduce(state, inner_reducer)
        apply_element(chunks, elem, inner_reducer, halt_reducer, halt_reducer.({:cont, h_elem, halt_state}), acc) 
    end
  end

  defp finish_chunks(chunks, inner_reducer) do
    chunks = :lists.reverse(chunks)
    for {_, chunk} <- chunks, do: ET.finish_reduce(chunk, inner_reducer)
  end

  defp apply_padding(chunks, :done, inner_reducer, reducer, r_signal) do
    halt_signal = ET.reduce_elements(finish_chunks(chunks, inner_reducer), r_signal, reducer)
    {halt_signal, []}
  end
  defp apply_padding(chunks, {elem, cont}, inner_reducer, halt_reducer, halt_signal) do
    case apply_element(chunks, elem, inner_reducer, halt_reducer, halt_signal) do
      {signal, []} -> {signal, []}
      {{:halt, _} = signal, chunks} -> {signal, chunks}
      {halt_signal, chunks} -> apply_padding(chunks, Transducible.next(cont), inner_reducer, halt_reducer, halt_signal)
    end
  end


  @doc """
  A transducer which makes a new input whenever the chunking function returns a new value.
  By default, each chunk is reduced into ET.Reducers.list(), but this can be overridden.

  """

  @spec chunk_by((term -> term)) :: ET.Transducer.t
  @spec chunk_by((term -> term), ET.reducer) :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t, (term -> term), ET.reducer) :: ET.Transducer.t
  def chunk_by(chunk_fun), do: chunk_by(chunk_fun, ET.Reducers.list())
  def chunk_by(%ET.Transducer{} = trans, chunk_fun), do: compose(trans, chunk_by(chunk_fun))
  def chunk_by(chunk_fun, inner_reducer) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state({nil, nil})
         {:cont, input, [{nil, nil} | r_state]} ->
           chunk_result = chunk_fun.(input) 
           do_chunk_by(input, chunk_result, chunk_result, inner_reducer.(:init), inner_reducer, reducer, r_state)
         {:cont, input, [{c_input, c_signal} | r_state]} ->
           do_chunk_by(input, chunk_fun.(input), c_input, c_signal, inner_reducer, reducer, r_state)
         {:fin, [{_c_input, c_signal} | r_state]} ->
           finish_chunk_by(c_signal, inner_reducer, reducer, r_state)
      end
    end]}
  end
  def chunk_by(%ET.Transducer{} = trans, chunk_fun, inner_reducer) do
    compose(trans, chunk_by(chunk_fun, inner_reducer))
  end

  defp do_chunk_by(_input, c_input, c_input, {:halt, _} = signal, _inner_reducer, _outer_reducer, r_state) do
    {:cont, r_state} |> prepend_state({c_input, signal})
  end
  defp do_chunk_by(input, c_input, c_input, {:cont, c_state}, inner_reducer, outer_reducer, r_state) do
    case inner_reducer.({:cont, input, c_state}) do
      {:cont, state} -> {:cont, r_state} |> prepend_state({c_input, {:cont, state}})
      {:halt, state} ->
        case outer_reducer.({:cont, ET.finish_reduce(state, inner_reducer), r_state}) do
          {:cont, state} -> {:cont, state} |> prepend_state({c_input, {:halt, state}})
          {:halt, state} -> {:halt, state} |> prepend_state({c_input, {nil,nil}})
        end
    end
  end
  defp do_chunk_by(input, c_input, _, {:cont, c_state}, inner_reducer, outer_reducer, r_state) do
    result = ET.finish_reduce(c_state, inner_reducer)
    case outer_reducer.({:cont, result, r_state}) do
      {:cont, r_state} ->
        do_chunk_by(input, c_input, c_input, inner_reducer.(:init), inner_reducer, outer_reducer, r_state)
      {:halt, state} -> {:halt, state} |> prepend_state({c_input, {nil,nil}})
    end
  end
  defp do_chunk_by(input, c_input, _, {:halt, _}, inner_reducer, outer_reducer, r_state) do
    do_chunk_by(input, c_input, c_input, inner_reducer.(:init), inner_reducer, outer_reducer, r_state)
  end

  defp finish_chunk_by({:cont, c_state}, inner_reducer, outer_reducer, r_state) do
    result = ET.finish_reduce(c_state, inner_reducer)
      {_, r_state} = outer_reducer.({:cont, result, r_state})
      outer_reducer.({:fin, r_state})
  end
  defp finish_chunk_by(_, _inner_reducer, outer_reducer, r_state) do
    outer_reducer.({:fin, r_state})
  end
  
  @doc """
  A transducer which caches a number of elements before sending them to be processed.
  Discard to true will discard cache on :fin signal.

    iex> three_cache = ET.Transducers.cache(3, true) |> ET.Reducers.list()
    iex> ET.reduce(1..2, three_cache)
    []
    iex> ET.reduce(1..3, three_cache)
    [1,2,3]

    iex> three_cache = ET.Transducers.cache(3) |> ET.Reducers.list()
    iex> ET.reduce(1..2, three_cache)
    [1,2]
    iex> ET.reduce(1..3, three_cache)
    [1,2,3]

  """

  @spec cache(ET.Transducer.t, non_neg_integer) :: ET.Transducer.t
  @spec cache(non_neg_integer) :: ET.Transducer.t
  @spec cache(ET.Transducer.t, non_neg_integer, boolean) :: ET.Transducer.t
  @spec cache(non_neg_integer, boolean) :: ET.Transducer.t
  def cache(size), do: cache(size, false)
  def cache(%ET.Transducer{} = trans, size), do: compose(trans, cache(size))
  def cache(size, discard) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state({size, []})
         {:cont, elem, [{1, elems} | rem_state]} ->
           case ET.reduce_elements(:lists.reverse([elem | elems]), {:cont, rem_state}, reducer) do
             {:halt, state} -> {:halt, state}
             {:done, state} -> {:cont, state}
           end
           |> prepend_state({size, []})
         {:cont, elem, [{n, elems} | rem_state]} -> {:cont, [{n-1,[elem | elems]} | rem_state]}
         {:fin, [{_n, elems} | rem_state]} ->
           unless discard do
             {_signal, rem_state} = ET.reduce_elements(:lists.reverse(elems), {:cont, rem_state}, reducer)
           end
           reducer.({:fin, rem_state})
      end
    end]}
  end
  def cache(%ET.Transducer{} = trans, size, discard) do
    compose(trans, cache(size, discard))
  end
  
  @doc """
  A transducer which will not relay :halt signals until it has recieved a specified
  number of elements. Elements received after a :halt signal is recieved are not
  passed to the reducer. It has no special effect if a :fin signal is received
  before a :halt.

  """
  
  @spec ensure(ET.Transducer.t, non_neg_integer) :: ET.Transducer.t
  @spec ensure(non_neg_integer) :: ET.Transducer.t
  def ensure(%ET.Transducer{} = trans, n), do: compose(trans, ensure(n))
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
  def map(%ET.Transducer{} = trans, fun), do: compose(trans, map(fun))
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
  def take(%ET.Transducer{} = trans, num), do: compose(trans, take(num))
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
  def zip(%ET.Transducer{} = trans), do: compose(trans, zip())
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
