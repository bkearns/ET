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
  def change?(change_check, first: first) do
    ref = :erlang.make_ref
    new(
      fn r_fun -> r_fun |> init |> cont(ref) end,
      fn elem, reducer, prev ->
        curr = change_check.(elem)
        same = curr == prev or (!first and (prev == ref))
        {elem, !same}
        |> reduce(reducer)
        |> cont(curr)
      end,
      fn reducer, _ -> finish(reducer) end
    )
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
  def chunk(inner_r_fun, padding) do
    new(
      fn r_fun -> r_fun |> init |> cont({nil, []}) end,
      fn {_, bool} = elem, reducer, {curr_chunk, chunks} ->
        chunks = if bool, do: chunks ++ [[]], else: chunks
        do_chunk(elem, curr_chunk, chunks, inner_r_fun, reducer)
      end,
      fn reducer, {curr_chunk, chunks} ->
        finish_chunk(curr_chunk, chunks, inner_r_fun, reducer, padding)
      end
    )

  end
  def chunk(%ET.Transducer{} = trans, inner_r_fun, padding) do
    compose(trans, chunk(inner_r_fun, padding))
  end


  defp do_chunk(_, nil, [], _, reducer) do
    cont(reducer, {nil, []})
  end
  defp do_chunk(_, curr_chunk, _, _, {_,{:done,_}} = reducer) do
    finish(curr_chunk)
    done(reducer, {nil, []})
  end
  defp do_chunk(elem, nil, [elems | chunks], inner_r_fun, reducer) do
    curr_chunk = elems |> :lists.reverse |> reduce_many((inner_r_fun |> init))
    do_chunk(elem, curr_chunk, chunks, inner_r_fun, reducer)
  end
  defp do_chunk(elem, {_,{:done,_}} = curr_chunk, chunks, inner_r_fun, reducer) do
    reducer = curr_chunk |> finish |> reduce(reducer)
    do_chunk(elem, nil, chunks, inner_r_fun, reducer)
  end
  defp do_chunk(elem, {_,{:cont,_}} = curr_chunk, chunks, inner_r_fun, reducer) do
    curr_chunk = elem |> reduce(curr_chunk)
    if done?(curr_chunk) do
      do_chunk(elem, curr_chunk, chunks, inner_r_fun, reducer)
    else
      cont(reducer, {curr_chunk, add_elem_to_chunks(elem, chunks)})
    end
  end

  defp add_elem_to_chunks(elem, chunks) do
    for chunk <- chunks, do: [elem | chunk]
  end

  defp finish_chunk(curr_chunk, _, _, reducer, nil) do
    if curr_chunk, do: finish(curr_chunk)
    finish(reducer)
  end
  defp finish_chunk(curr_chunk, chunks, inner_r_fun, {_,{signal,_}}=reducer, _) when
  signal == :done or (curr_chunk == nil and chunks == []) do
    finish_chunk(curr_chunk, chunks, inner_r_fun, reducer, nil)
  end
  defp finish_chunk(curr_chunk, chunks, inner_r_fun, {r_fun,_}=reducer, padding) do
    case Transducible.next(padding) do
      {elem, padding} ->
        {signal, [{curr_chunk, chunks} | r_state]} =
          do_chunk({elem, nil}, curr_chunk, chunks, inner_r_fun, reducer)
          finish_chunk(curr_chunk, chunks, inner_r_fun, {r_fun,{signal,r_state}}, padding)
      :done ->
        reducer = curr_chunk |> finish |> reduce(reducer)
        finish_chunks(chunks, inner_r_fun, reducer)
    end
  end

  defp finish_chunks(chunks, inner_r_fun, {_,{signal,_}} = reducer) when
  chunks == [] or signal == :done do
    finish_chunk(nil, [], inner_r_fun, reducer, nil)
  end
  defp finish_chunks([elems | chunks], inner_r_fun, reducer) do
    reducer =
      elems |> :lists.reverse |> reduce_many(inner_r_fun |> init)
      |> finish |> elem(1) |> reduce(reducer)
    finish_chunks(chunks, inner_r_fun, reducer)
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
    new(
      fn
        {_,bool} = elem, reducer when bool in [false, nil] ->
          elem |> reduce(reducer) |> cont
        _, reducer ->
          cont(reducer)
      end
    )
  end


  @doc """
  A transducer which sends elements to the reducer, but when it receives
  {_, true}, it sends that element and forces a :halt signal on the return.

  """

  @spec halt_after() :: ET.Transducer.t
  @spec halt_after(ET.Transducer.t) :: ET.Transducer.t
  def halt_after(%ET.Transducer{} = trans), do: compose(trans, halt_after)
  def halt_after() do
    new(
      fn
        {_, bool} = elem, reducer when bool in [false, nil] ->
          elem |> reduce(reducer) |> cont
        elem, reducer ->
          elem |> reduce(reducer) |> done
      end
    )
  end

  @doc """
  A transducer which sends elements to the reducer, but when it receives
  {_, true}, it immediately sends :halt without reducing the current element.

  """

  @spec halt_on() :: ET.Transducer.t
  @spec halt_on(ET.Transducer.t) :: ET.Transducer.t
  def halt_on(%ET.Transducer{} = trans), do: compose(trans, halt_on)
  def halt_on() do
    new(
      fn
        {_, bool} = elem, reducer when bool in [false, nil] ->
          elem |> reduce(reducer) |> cont
        _, reducer ->
          reducer |> done
      end
    )
  end


  @doc """
  A transducer which takes elements of {elem, value} and manages different
  reducers for each unique value. By default this reducer is ET.Reducers.list,
  but may be overridden. Additionally, a Dict of reducer functions can be
  included where keys are values and those elements will be reduced separately.

  Once an inner reducer :halts, it will be immediately reduced as
  {value, result} and no more elements of that value will be processed. If there
  are remaining reducers on a :fin signal, they will be reduced in the same
  method at that time.

  """

  def group_by(r_fun), do: group_by(r_fun, %{})
  def group_by(%ET.Transducer{} = trans, r_fun) do
    compose(trans, group_by(r_fun))
  end
  def group_by(r_fun, r_funs) do
    new(
      fn r_fun -> r_fun |> init |> cont(HashDict.new) end,
      fn {_,value} = elem, reducer, groups ->
        Dict.get(groups, value,
          Dict.get(r_funs, value, r_fun) |> init)
        |> do_group_by(elem, reducer, groups)
      end,
      fn reducer, groups ->
        ET.reduce(groups, finish_group_reducer)
        |> reduce_many(reducer)
        |> finish
      end
    )
  end
  def group_by(%ET.Transducer{} = trans, r_fun, r_funs) do
    compose(trans, group_by(r_fun, r_funs))
  end

  defp do_group_by(:done, _, reducer, groups), do: cont(reducer, groups)
  defp do_group_by(v_reducer, {_,value} = elem, reducer, groups) do
    v_reducer = elem |> reduce(v_reducer)
    if done?(v_reducer) do
      result = finish(v_reducer)
      reducer = {value, result} |> reduce(reducer)
      if done?(reducer) do
        ET.reduce(groups, finish_group_reducer)
        done(reducer, %{})
      else
        cont(Dict.put(groups, value, :done))
      end
    else
      reducer
      |> cont(Dict.put(groups, value, v_reducer))
    end
  end

  defp finish_group_reducer do
       ET.Transducers.filter(&( elem(&1,1) != :done ))
    |> ET.Transducers.map(fn {value, v_reducer} ->
                {value, finish(v_reducer)}
              end)
    |> ET.Reducers.list
  end


  @doc """
  A transducer which negates the first n truthy values it receives.

  """

  def ignore(n) do
    new(
      fn r_fun -> r_fun |> init |> cont(n) end,
      fn
        {_,bool} = elem, reducer, n when n == 0 or bool in [false, nil] ->
          {elem, bool} |> reduce(reducer) |> cont(n)
        elem, reducer, n ->
          {elem, false} |> reduce(reducer) |> cont(n-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
  end
  def ignore(%ET.Transducer{} = trans, n), do: compose(trans, ignore(n))


  @doc """
  A transducer which inserts the supplied element before each {elem, truthy}
  element it receives.

  """

  def insert_before(term) do
    new(
      fn
        {_,bool} = elem, reducer when bool in [false, nil] ->
          elem |> reduce(reducer) |> cont
        elem, reducer ->
          reducer = term |> reduce(reducer)
          elem |> reduce(reducer) |> cont
      end
    )
  end
  def insert_before(%ET.Transducer{} = trans, term) do
    compose(trans, insert_before(term))
  end

  @doc """
  A transducer which takes elements of the form {_, test} and produces
  elements in the form {{_, test}, boolean} where boolean is true if
  the element is contained within the transducible collection. The
  transducible will be fully traversed the first time a non-contained
  element is found.

  Optionally takes one_for_one: true which will only produces true once for each
  element in transducible. Duplicate items produce true one for each duplicate
  item.

  """

  @spec in_collection(ET.Transducer.t, ET.Transducible.t) :: ET.Transducer.t
  @spec in_collection(ET.Transducible.t) :: ET.Transducer.t
  @spec in_collection(ET.Transducible.t, list({:one_for_one, boolean})) :: ET.Transducer.t
  @spec in_collection(ET.Transducer.t, ET.Transducible.t, list({:one_for_one, boolean})) :: ET.Transducer.t
  def in_collection(transducible), do: in_collection(transducible, one_for_one: false)
  def in_collection(%ET.Transducer{} = trans, transducible) do
    compose(trans, in_collection(transducible))
  end
  def in_collection(transducible, one_for_one: false) do
    new(
      fn r_fun -> r_fun |> init |> cont({transducible, HashSet.new}) end,
      fn
        {_,test} = elem, reducer, {:done, set} = state ->
          {elem, Set.member?(set, test)}
          |> reduce(reducer)
          |> cont(state)

        {_,test} = elem, reducer, {t, set} ->
          {result, t, set} = in_collection_set_test(test, t, set)
          {elem, result}
          |> reduce(reducer)
          |> cont({t, set})
      end,
      fn reducer, _ -> finish(reducer) end
    )
  end

  def in_collection(transducible, one_for_one: true) do
    new(
      fn r_fun -> r_fun |> init |> cont({transducible, HashDict.new}) end,
      fn
        {_,test} = elem, reducer, {:done, dict} ->
          {result, dict, _} = in_collection_dict_test(test, dict, [])
          {elem, result}
          |> reduce(reducer)
          |> cont({:done, dict})

        {_,test} = elem, reducer, {t, dict} ->
           {result, dict, t} =
             in_collection_dict_test(test, dict, t)
           {elem, result}
           |> reduce(reducer)
           |> cont({t, dict})
      end,
      fn reducer, _ -> finish(reducer) end
    )
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
  A transducer which takes {elem, value} and outputs value.

  """

  @spec reverse_destructure() :: ET.Transducer.t
  @spec reverse_destructure(ET.Transducer.t) :: ET.Transducer.t
  def reverse_destructure() do
    new(
      fn {_, v}, reducer ->
        v |> reduce(reducer) |> cont
      end
    )
  end
  def reverse_destructure(%ET.Transducer{} = trans) do
    compose(trans, reverse_destructure)
  end


  @doc """
  A transducer which takes element and outputs {element, fun.(element)}.

  """

  @spec structure(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec structure((term -> term)) :: ET.Transducer.t
  def structure(%ET.Transducer{} = trans, fun), do: compose(trans, structure(fun))
  def structure(fun) do
    new(
      fn elem, reducer ->
        {elem, fun.(elem)}
        |> reduce(reducer)
        |> cont
      end
    )
  end


  @doc """
  A transducer which takes elements in the form {_, t} and outputs in the form
  {{_, t}, !t}.

  """

  @spec negate(ET.Transducer.t) :: ET.Transducer.t
  @spec negate() :: ET.Transducer.t
  def negate(%ET.Transducer{} = trans), do: compose(trans, negate)
  def negate() do
    new(
      fn {_,bool} = elem, reducer ->
        {elem, !bool}
        |> reduce(reducer)
        |> cont
      end
    )
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
    new(
      fn r_fun -> r_fun |> init |> cont(start) end,
      fn
        elem, reducer, 0 ->
          {elem, true}
          |> reduce(reducer)
          |> cont(n-1)
        elem, reducer, count ->
          {elem, false}
          |> reduce(reducer)
          |> cont(count-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
  end
  def true_every(%ET.Transducer{} = trans, n, first) do
    compose(trans, true_every(n, first))
  end

  @doc """
  A transducer which takes elements and wraps them in their 0-based index.

  """

  def with_index(%ET.Transducer{} = trans), do: compose(trans, with_index)
  def with_index() do
    new(
      fn r_fun -> r_fun |> init |> cont(0) end,
      fn elem, reducer, index ->
        {elem, index}
        |> reduce(reducer)
        |> cont(index+1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
  end
end
