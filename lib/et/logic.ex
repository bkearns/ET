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


end