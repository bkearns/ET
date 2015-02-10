defmodule ET.Logic do
  @moduledoc """
  Provides logic transducers of various sorts. These are transducers
  which interact with elements in the form {elem, logic} where logic
  is usually boolean. These are elements for constructing larger
  transducers which are more useful day-to-day.

  It is difficult to decide standards for this communication method.
  These are implemented as much as possible where {_, true} is the
  active or exceptional state while {_, false} is the passive or normal
  state. For example, filter will pass elements to its reducer when it
  receives {_, false} and eliminate them when it receives {_, true}, 
  which might be the opposite of what might be expected.

  """

  import ET.Transducer

  @doc """


  """

  def change?(), do: change?(&(&1), first: false)
  def change?(%ET.Transducer{} = trans) do
    trans |> compose(change?)
  end
  def change?([first: first]) do
    change?(&(&1), first: first)
  end
  def change?(change_check) do
    change?(change_check, first: false)
  end
  def change?(%ET.Transducer{} = trans, one) do
    compose(trans, change?(one))
  end
  def change?(change_check, [first: first]) do
    ref = :erlang.make_ref
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state(ref)
         {:cont, [prev | r_state], elem} ->
           curr = change_check.(elem)
           same = curr == prev or (!first and (prev == ref))
           reducer.({:cont, r_state, {elem, !same}})
           |> prepend_state(curr)
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
       end
    end]}
  end
  def change?(%ET.Transducer{} = trans, change_check, first) do
    compose(trans, change?(change_check, first))
  end

  
  @doc """
  A transducer which applies each element to an arbitrary number of 
  inner reducers. New inner reducers are generated on a {_, true} element.
  Each chunk is started and completed in order of creation. Elements are
  cached for future chunks and applied immediately upon the completion of
  the previous chunk.

  Chunks only end when the inner reducer returns :halt or the :fin signal
  is received from above.

  If a padding transducible is provided, on finish, any remaining inner
  reducers will be fed from that until they :halt (as above) or the
  padding is :done. In this case, they will all be finished and sent to
  the main reducer. Padding elements are mapped to {element, nil}.

  If no padding transducible (nil) is provided, on :fin, all inner reducers
  will be finished, but they will not be sent to the main reducer.

  """
  def chunk(inner_reducer), do: chunk(inner_reducer, nil)
  def chunk(%ET.Transducer{} = trans, inner_reducer) do
    compose(trans, chunk(inner_reducer))
  end
  def chunk(inner_reducer, padding) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state({nil, []})
         {:cont, [{curr_chunk, chunks} | r_state], {_, bool} = elem} ->
           chunks = if bool, do: chunks ++ [[]], else: chunks
           do_chunk(elem, curr_chunk, chunks, inner_reducer, reducer, {:cont, r_state})
         {:fin, [{curr_chunk, chunks} | r_state]} ->
           finish_chunk(curr_chunk, chunks, inner_reducer, reducer, {:cont, r_state}, padding)
      end
    end]}
  end
  def chunk(%ET.Transducer{} = trans, inner_reducer, padding) do
    compose(trans, chunk(inner_reducer, padding))
  end


  defp do_chunk(_, nil, [], _, _, r_signal) do
    r_signal |> prepend_state({nil, []})
  end
  defp do_chunk(_, {_, c_state}, _, inner_reducer, _, {:halt, r_state}) do
    inner_reducer.({:fin, c_state})
    {:halt, r_state} |> prepend_state({nil, []})
  end
  defp do_chunk(elem, nil, [elems | chunks], inner_reducer, outer_reducer, r_signal) do
    {c_signal, c_state, _} = ET.reduce_elements(:lists.reverse(elems), inner_reducer.(:init), inner_reducer)
    do_chunk(elem, {c_signal, c_state}, chunks, inner_reducer, outer_reducer, r_signal)
  end
  defp do_chunk(elem, {:halt, c_state}, chunks, inner_reducer, outer_reducer, {:cont, r_state}) do
    r_signal = outer_reducer.({:cont, r_state, ET.finish_reduce(c_state, inner_reducer)})
    do_chunk(elem, nil, chunks, inner_reducer, outer_reducer, r_signal)
  end
  defp do_chunk(elem, {:done, c_state}, chunks, inner_reducer, outer_reducer, r_signal) do
    case inner_reducer.({:cont, c_state, elem}) do
      {:halt, c_state} ->
        do_chunk(elem, {:halt, c_state}, chunks, inner_reducer, outer_reducer, r_signal)
      {:cont, c_state} ->
        r_signal |> prepend_state({{:done, c_state}, add_elem_to_chunks(elem, chunks)})
    end
  end
  
  defp add_elem_to_chunks(elem, chunks) do
    for chunk <- chunks, do: [elem | chunk]
  end

  defp finish_chunk(curr_chunk, _, inner_reducer, outer_reducer, {_, r_state}, nil) do
    if curr_chunk do
      {_, c_state} = curr_chunk
      inner_reducer.({:fin, c_state})
    end
    outer_reducer.({:fin, r_state})
  end
  defp finish_chunk(curr_chunk, chunks, inner_reducer, outer_reducer, {signal, r_state}, _) when
  signal == :halt or (curr_chunk == nil and chunks == []) do
    finish_chunk(curr_chunk, chunks, inner_reducer, outer_reducer, {:halt, r_state}, nil)
  end
  defp finish_chunk(curr_chunk, chunks, inner_reducer, outer_reducer, r_signal, padding) do
    case Transducible.next(padding) do
      {elem, padding} ->
        {signal, [{curr_chunk, chunks} | r_state]} = 
          do_chunk({elem, nil}, curr_chunk, chunks, inner_reducer, outer_reducer, r_signal)
        finish_chunk(curr_chunk, chunks, inner_reducer, outer_reducer, {signal, r_state}, padding)
      :done ->
        {:cont, r_state} = r_signal
        {:done, c_state} = curr_chunk
        r_signal = outer_reducer.({:cont, r_state, ET.finish_reduce(c_state, inner_reducer)})
        finish_chunks(chunks, inner_reducer, outer_reducer, r_signal)
    end
  end
  
  defp finish_chunks(chunks, inner_reducer, outer_reducer, {signal, r_state}) when
  chunks == [] or signal == :halt do
    finish_chunk(nil, [], inner_reducer, outer_reducer, {signal, r_state}, nil)
  end
  defp finish_chunks([chunk | chunks], inner_reducer, outer_reducer, {:cont, r_state}) do
    {_, c_state, _} = ET.reduce_elements(:lists.reverse(chunk), inner_reducer.(:init), inner_reducer)
    r_signal = outer_reducer.({:cont, r_state, ET.finish_reduce(c_state, inner_reducer)})
    finish_chunks(chunks, inner_reducer, outer_reducer, r_signal)
  end


  @doc """
  A transducer which transforms {elem, _} into elem. Used with various
  generic transducers which take elements in this form. If an integer is
  provided, it destructures that many times

    iex> reducer = ET.Transducers.destructure |> ET.Reducers.list
    iex> ET.reduce([{1, false}, {2, true}], reducer)
    [1, 2]

  """

  @spec destructure() :: ET.Transducer.t
  @spec destructure(ET.Transducer.t) :: ET.Transducer.t
  @spec destructure(integer) :: ET.Transducer.t
  @spec destructure(ET.Transducer.t, integer) :: ET.Transducer.t
  def destructure(), do: destructure(1)
  def destructure(%ET.Transducer{} = trans), do: compose(trans, destructure)
  def destructure(1) do
    ET.Transducers.map(fn {elem, _} -> elem end)
  end
  def destructure(n) do
    compose(destructure(n-1), destructure(1))
  end
  def destructure(%ET.Transducer{} = trans, n), do: compose(trans, destructure(n))
  
  @doc """
  A transducer which reduces elements of form {_, false} and does not reduce
  elements of form {_, true}.

  """

  @spec filter(ET.Transducer.t) :: ET.Transducer.t
  @spec filter() :: ET.Transducer.t
  def filter(%ET.Transducer{} = trans), do: compose(trans, filter)
  def filter() do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, _, {_, bool}} = signal when bool == false or bool == nil ->
           reducer.(signal)
         {:cont, r_state, _} ->
           {:cont, r_state}
         {:fin, r_state} -> reducer.({:fin, r_state})
      end
    end]}
  end


  @doc """
  A transducer which sends elements to the reducer, but when it receives
  {_, true}, it sends that element and forces a :halt signal on the return.

  """

  @spec halt_after() :: ET.Transducer.t
  @spec halt_after(ET.Transducer.t) :: ET.Transducer.t
  def halt_after(%ET.Transducer{} = trans), do: compose(trans, halt_after)
  def halt_after() do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, _, {_, bool}} = signal when bool == false or bool == nil ->
           reducer.(signal)
         {:cont, _, _} = signal ->
           {_, state} = reducer.(signal)
           {:halt, state}
         {:fin, state} -> reducer.({:fin, state})
      end
    end]}
  end

  @doc """
  A transducer which sends elements to the reducer, but when it receives
  {_, true}, it immediately sends :halt without reducing the current element.

  """

  @spec halt_on() :: ET.Transducer.t
  @spec halt_on(ET.Transducer.t) :: ET.Transducer.t
  def halt_on(%ET.Transducer{} = trans), do: compose(trans, halt_on)
  def halt_on() do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, _, {_, bool}} = signal when bool == false or bool == nil ->
           reducer.(signal)
         {:cont, state, _} ->
           {:halt, state}
         {:fin, state} -> reducer.({:fin, state})
      end
    end]}
  end


  @doc """
  A transducer which takes elements of the form {_, test} and produces
  elements in the form {{_, test}, boolean} where boolean is true if
  the element is contained within the transducible collection. The
  transducible will be fully traversed the first time a non-contained
  element is found.

  Optionally takes one_for_one: true which will only produces true once for each
  element in transducible. Duplicate items produce true one for each duplicate item.

  """

  @spec in_collection(ET.Transducer.t, ET.Transducible.t) :: ET.Transducer.t
  @spec in_collection(ET.Transducible.t) :: ET.Transducer.t
  @spec in_collection(ET.Transducible.t, list({:one_for_one, boolean})) :: ET.Transducer.t
  @spec in_collection(ET.Transducer.t, ET.Transducible.t, list({:one_for_one, boolean})) :: ET.Transducer.t
  def in_collection(transducible), do: in_collection(transducible, one_for_one: false)
  def in_collection(%ET.Transducer{} = trans, transducible) do
    compose(trans, in_collection(transducible))
  end
  def in_collection(transducible, [one_for_one: false]) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state({transducible, HashSet.new})
         {:cont, [{:done, set} | r_state], {_, test} = elem} ->
           reducer.({:cont, r_state, {elem, Set.member?(set, test)}})
           |> prepend_state({:done, set})
         {:cont, [{t, set} | r_state], {_, test} = elem} ->
           {result, t, set} = in_collection_set_test(test, t, set)
           reducer.({:cont, r_state, {elem,result}})
           |> prepend_state({t, set})
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
       end
    end]}
  end
  def in_collection(transducible, [one_for_one: true]) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state({transducible, HashDict.new})
         {:cont, [{:done, dict} | r_state], {_, test} = elem} ->
           {result, dict, _} = in_collection_dict_test(test, dict, [])
           reducer.({:cont, r_state, {elem, result}})
           |> prepend_state({:done, dict})
         {:cont, [{transducible, dict} | r_state], {_, test} = elem} ->
           {result, dict, transducible} =
             in_collection_dict_test(test, dict, transducible)
           reducer.({:cont, r_state, {elem, result}})
           |> prepend_state({transducible, dict})
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
      end
    end]}
  end
  def in_collection(%ET.Transducer{} = trans, transducible, keywords) do
    compose(trans, in_collection(transducible, keywords))
  end
  

  defp in_collection_set_test(test, t, set) do
    if Set.member?(set, test) do
      {true, t, set}
    else
      {result, t, keys} = in_collection_find_element(t, test)
      {result, t, :lists.foldl(&(Set.put(&2,&1)), set, keys)}
    end
  end

  defp in_collection_dict_test(test, dict, transducible) do
    case Dict.fetch(dict, test) do
      {:ok, 1} ->
        {true, Dict.delete(dict, test), transducible}
      {:ok, n} -> {true, Dict.put(dict, test, n-1), transducible}
      :error   ->
        {result, transducible, keys} =
          case in_collection_find_element(transducible, test) do
            {true, t, [_ | keys]} -> {true, t, keys}
            {false, :done, keys}  -> {false, :done, keys}
          end
        dict = :lists.foldl(&(Dict.update(&2,&1,1,fn x->x+1 end)), dict, keys)
        cond do
          result                -> {true,  dict, transducible}
          Dict.keys(dict) == [] -> {nil,   dict, transducible}
          true                  -> {false, dict, transducible}
        end
    end     
  end

  defp in_collection_find_element(t, test) do
    in_collection_find_element(Transducible.next(t), test, [])
  end
  defp in_collection_find_element(:done, _test, acc) do
    {false, :done, acc}
  end
  defp in_collection_find_element({test, t}, test, acc) do
    {true, t, [test | acc]}
  end
  defp in_collection_find_element({elem, t}, test, acc) do
    in_collection_find_element(Transducible.next(t), test, [elem | acc])
  end


  @doc """
  A transducer which takes element and outputs {element, fun.(element)}.

  """

  @spec structure(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec structure((term -> term)) :: ET.Transducer.t  
  def structure(%ET.Transducer{} = trans, fun), do: compose(trans, structure(fun))
  def structure(fun) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, r_state, elem} -> reducer.({:cont, r_state, {elem, fun.(elem)}})
         {:fin, r_state} -> reducer.({:fin, r_state})
      end
    end]}
  end


  @doc """
  A transducer which takes elements in the form {_, t} and outputs in the form
  {{_, t}, !t}.

  """

  @spec negate(ET.Transducer.t) :: ET.Transducer.t
  @spec negate() :: ET.Transducer.t
  def negate(%ET.Transducer{} = trans), do: compose(trans, negate)
  def negate() do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, r_state, {_, bool} = elem} -> reducer.({:cont, r_state, {elem, !bool}})
         {:fin, r_state} -> reducer.({:fin, r_state})
      end
    end]}
  end

  
  @doc """
  A transducer which sends {true, element} every n elements received.
  If first: true is also sent, the transducer will start with a true.

  """

  @spec true_every(non_neg_integer) :: ET.Transducer.t
  @spec true_every(ET.Transducer.t, non_neg_integer) :: ET.Transducer.t
  @spec true_every(non_neg_integer, [{:first, boolean}]) :: ET.Transducer.t
  @spec true_every(ET.Transducer.t, non_neg_integer, [{:first, boolean}]) :: ET.Transducer.t
  def true_every(n), do: true_every(n, first: false)
  def true_every(%ET.Transducer{} = trans, n) do
    compose(trans, true_every(n))
  end
  def true_every(n, [first: first]) do
    start = if first, do: 0, else: n-1
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state(start)
         {:cont, [0 | r_state], elem} ->
           reducer.({:cont, r_state, {elem, true}})
           |> prepend_state(n-1)
         {:cont, [count | r_state], elem} ->
           reducer.({:cont, r_state, {elem, false}})
           |> prepend_state(count-1)
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
      end
    end]}
  end
  def true_every(%ET.Transducer{} = trans, n, first) do
    compose(trans, true_every(n, first))
  end

  @doc """
  A transducer which takes elements and wraps them in their 0-based index.

  """

  def with_index(%ET.Transducer{} = trans), do: compose(trans, with_index)
  def with_index() do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init) |> prepend_state(0)
         {:cont, [index | r_state], elem} ->
           reducer.({:cont, r_state, {elem, index}})
           |> prepend_state(index + 1)
         {:fin, [_ | r_state]} -> reducer.({:fin, r_state})
      end
    end]}
  end
end
