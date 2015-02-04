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
  Elements are applied to inner reducers in the order they were generated.
  Inner reducers must :halt on their own and whenever the oldest inner
  reducer is in :halt, it will be finished and passed to the main reducer.

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
      fn :init ->
           r_signal = {signal, _} = reducer.(:init)
           r_signal |> prepend_state({signal, []})
         {:cont, [{signal, chunks} | r_state], elem} ->
           do_chunk(elem, chunks, inner_reducer, reducer, {signal, r_state})
         {:fin, [{signal, chunks} | r_state]} ->
           finish_chunk(chunks, inner_reducer, reducer, {signal, r_state}, padding)
      end
    end]}
  end
  def chunk(%ET.Transducer{} = trans, inner_reducer, padding) do
    compose(trans, chunk(inner_reducer, padding))
  end

  defp do_chunk({_, bool} = elem, chunks, inner_reducer, outer_reducer, r_signal) when bool == false or bool == nil do
    apply_element(elem, chunks, inner_reducer, outer_reducer, r_signal)
  end
  defp do_chunk(elem, chunks, inner_reducer, outer_reducer, r_signal) do
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
        {:cont, state} -> inner_reducer.({:cont, state, elem})
        {:halt, _} -> chunk
      end
    case {c_signal, acc} do
      {{:halt, state}, []} ->
        r_elem = ET.finish_reduce(state, inner_reducer)
        r_signal = outer_reducer.({:cont, r_state, r_elem})
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
    case apply_element({elem, nil}, chunks, inner_reducer, outer_reducer, r_signal) do
      {_, [{_, []} | r_state]}     -> r_state
      {:halt,  [{_, chunks} | r_state]} ->
        finish_chunks(chunks, inner_reducer)
        r_state
      {signal, [{_, chunks} | r_state]} ->
        apply_padding(Transducible.next(cont), chunks, inner_reducer, outer_reducer, {signal, r_state})
    end
  end
  

  @doc """
  A transducer which transforms {elem, _} into elem. Used with various
  generic transducers which take elements in this form.

    iex> reducer = ET.Transducers.destructure |> ET.Reducers.list
    iex> ET.reduce([{1, false}, {2, true}], reducer)
    [1, 2]

  """

  @spec destructure(ET.Transducer.t) :: ET.Transducer.t
  @spec destructure() :: ET.Transducer.t
  def destructure(%ET.Transducer{} = trans), do: compose(trans, destructure)
  def destructure() do
    ET.Transducers.map(fn {elem, _} -> elem end)
  end
  
  
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
