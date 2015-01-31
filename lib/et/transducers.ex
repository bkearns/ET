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

  A generic version of chunk is available which takes a raw inner reducer and a padding transducer.
  This version expects {boolean, value} tuples and triggers a new chunk each time boolean is true.
  The inner reducer should expect to receive the tuples allowing it to react dependent upon the
  result of whatever is creating them.

  """

  # TODO spec definition for chunk
  def chunk(size), do: chunk(size, size)
  def chunk(%ET.Transducer{} = trans, two) do
    compose(trans, chunk(two))
  end
  def chunk(size, step) when is_integer(size) and is_integer(step) do
    chunk(size, step, nil)
  end
  def chunk(size, reducer) when is_integer(size) and is_function(reducer, 1) do
    chunk(size, size, nil, reducer)
  end
  def chunk(size, padding) when is_integer(size) do
    chunk(size, size, padding)
  end
  def chunk(inner_reducer, padding) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init ->
           r_signal = {signal, _} = reducer.(:init)
           r_signal |> prepend_state({signal, []})
         {:cont, elem, [{signal, chunks} | r_state]} ->
           do_chunk(elem, chunks, inner_reducer, reducer, {signal, r_state})
         {:fin, [{signal, chunks} | r_state]} ->
           finish_chunk(chunks, inner_reducer, reducer, {signal, r_state}, padding)
      end
    end]}
  end
  def chunk(%ET.Transducer{} = trans, two, three) do
    compose(trans, chunk(two, three))
  end
  def chunk(size, step, reducer) when is_integer(size) and is_integer(step) and is_function(reducer, 1) do
    chunk(size, step, nil, reducer)
  end
  def chunk(size, step, padding) when is_integer(size) and is_integer(step) do
    chunk(size, step, padding, ET.Reducers.list())
  end
  def chunk(%ET.Transducer{} = trans, two, three, four) do
    compose(trans, chunk(two, three, four))
  end
  def chunk(size, step, padding, reducer) do
    inner_reducer =
      destructure
      |> take(size)
      |> compose(reducer)

    step_trans(step)
    |> chunk(inner_reducer, padding)
  end
  def chunk(%ET.Transducer{} = trans, two, three, four, five) do
    compose(trans, chunk(two, three, four, five))
  end
  

  defp do_chunk({false, _} = elem, chunks, inner_reducer, outer_reducer, r_signal) do
    apply_element(elem, chunks, inner_reducer, outer_reducer, r_signal)
  end
  defp do_chunk({true, _} = elem, chunks, inner_reducer, outer_reducer, r_signal) do
    apply_element(elem, [inner_reducer.(:init) | chunks], inner_reducer, outer_reducer, r_signal)
  end
  
  defp apply_element(elem, chunks, inner_reducer, outer_reducer, r_signal) do
    apply_element(elem, :lists.reverse(chunks), inner_reducer, outer_reducer, r_signal, [])
  end
  defp apply_element(_, [], _, _, {signal, _} = r_signal, acc) do
    r_signal |> prepend_state({signal, acc})
  end
  defp apply_element(elem, [chunk | chunks], inner_reducer, outer_reducer, {:halt, _} = r_signal, acc) do
    apply_element(elem, chunks, inner_reducer, outer_reducer, r_signal, [chunk | acc])
  end
  defp apply_element(elem, [chunk | chunks], inner_reducer, outer_reducer, {:cont, r_state}, acc) do
    c_signal =
      case chunk do
        {:cont, state} -> inner_reducer.({:cont, elem, state})
        {:halt, _} -> chunk
      end
    case {c_signal, acc} do
      {{:halt, state}, []} ->
        r_elem = ET.finish_reduce(state, inner_reducer)
        r_signal = outer_reducer.({:cont, r_elem, r_state})
        apply_element(elem, chunks, inner_reducer, outer_reducer, r_signal, acc)
      _ ->
        apply_element(elem, chunks, inner_reducer, outer_reducer, {:cont, r_state}, [c_signal | acc])
    end
  end

  defp finish_chunk(chunks, inner_reducer, outer_reducer, {signal, r_state}, padding) when signal == :halt or padding == nil do
    finish_chunks(chunks, inner_reducer)
    outer_reducer.({:fin, r_state})
  end
  defp finish_chunk(chunks, inner_reducer, outer_reducer, {:cont, _} = r_signal, padding) do
    r_state = apply_padding(Transducible.next(padding), chunks, inner_reducer, outer_reducer, r_signal)
    outer_reducer.({:fin, r_state})
  end

  defp finish_chunks(chunks, inner_reducer) do
    chunks = :lists.reverse(chunks)
    for {_, chunk} <- chunks, do: ET.finish_reduce(chunk, inner_reducer)
  end

  defp apply_padding(:done, chunks, inner_reducer, outer_reducer, r_signal) do
    {_signal, r_state, _} = ET.reduce_elements(finish_chunks(chunks, inner_reducer), r_signal, outer_reducer)
    r_state
  end
  defp apply_padding({elem, cont}, chunks, inner_reducer, outer_reducer, r_signal) do
    case apply_element({nil, elem}, chunks, inner_reducer, outer_reducer, r_signal) do
      {_, [{_, []} | r_state]}     -> r_state
      {:halt,  [{_, chunks} | r_state]} ->
        finish_chunks(chunks, inner_reducer)
        r_state
      {signal, [{_, chunks} | r_state]} ->
        apply_padding(Transducible.next(cont), chunks, inner_reducer, outer_reducer, {signal, r_state})
    end
  end

  defp step_trans(n) when is_integer(n) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state(1)
         {:cont, elem, [1 | r_state]} ->
           reducer.({:cont, {true, elem}, r_state})
           |> prepend_state(n)
         {:cont, elem, [countdown | r_state]} ->
           reducer.({:cont, {false, elem}, r_state})
           |> prepend_state(countdown - 1)
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
      end
    end]}
  end

  defp destructure() do
    map(fn {_, elem} -> elem end)
  end

  @doc """
  A transducer which makes a new input whenever the chunking function returns a new value.
  By default, each chunk is reduced into ET.Reducers.list(), but this can be overridden.

  """

  @spec chunk_by() :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t) :: ET.Transducer.t
  @spec chunk_by((term -> term)) :: ET.Transducer.t
  @spec chunk_by((term -> term), ET.reducer) :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t, (term -> term), ET.reducer) :: ET.Transducer.t
  def chunk_by(), do: chunk_by(&(&1))
  def chunk_by(%ET.Transducer{} = trans), do: compose(trans, chunk_by())
  def chunk_by(change_fun), do: chunk_by(change_fun, ET.Reducers.list())
  def chunk_by(%ET.Transducer{} = trans, change_fun), do: compose(trans, chunk_by(change_fun))
  def chunk_by(change_fun, inner_reducer) do
    compose(change_trans(change_fun),
            chunk(compose(change_halter, inner_reducer), []))
  end
  def chunk_by(%ET.Transducer{} = trans, change_fun, inner_reducer) do
    compose(trans, chunk_by(change_fun, inner_reducer))
  end

  defp change_trans(%ET.Transducer{} = trans, change_fun) do
    compose(trans, change_trans(change_fun))
  end
  defp change_trans(change_fun) do
    ref = :erlang.make_ref
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state(ref)
         {:cont, elem, [prev | r_state]} ->
           curr = change_fun.(elem)
           reducer.({:cont, {curr != prev, elem}, r_state})
           |> prepend_state(curr)
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
       end
    end]}
  end

  defp change_halter(%ET.Transducer{} = trans), do: compose(trans, change_reducer())
  defp change_halter do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state(true)
         {:cont, {true, elem}, [true | r_state]} ->
           reducer.({:cont, elem, r_state})
           |> prepend_state(false)
         {:cont, {false, elem}, [false | r_state]} ->
           reducer.({:cont, elem, r_state})
           |> prepend_state(false)
         {:cont, {true, _elem}, [false | r_state]} ->
           {:halt, [false | r_state]}
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
       end
    end]}
  end


  @doc """
  A transducer which takes transducibles and reduces them.

    iex> reducer = ET.Transducers.concat |> ET.Reducers.list
    iex> ET.reduce([1..3, [4, 5]], reducer)
    [1,2,3,4,5]

  """

  @spec concat(ET.Transducer.t) :: ET.Transducer.t
  @spec concat() :: ET.Transducer.t
  def concat(%ET.Transducer{} = trans), do: compose(trans, concat)
  def concat() do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, elem, r_state} ->
           case ET.reduce_elements(elem, {:cont, r_state}, reducer) do
             {:halt, state, _} -> {:halt, state}
             {:done, state, _} -> {:cont, state}
           end
         {:fin, r_state} -> reducer.({:fin, r_state})
      end
    end]}
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
