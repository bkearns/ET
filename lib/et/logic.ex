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
  A transducer which reduces elements of form {_, false} and does not reduce
  elements of form {_, true}.

  """

  @spec filter(ET.Transducer.t) :: ET.Transducer.t
  @spec filter() :: ET.Transducer.t
  def filter(%ET.Transducer{} = trans), do: compose(trans, filter)
  def filter() do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, r_state, {_, bool}} when bool == false or bool == nil ->
           {:cont, r_state}
         {:cont, r_state, _} = signal ->
           reducer.(signal)
         {:fin, r_state} -> reducer.({:fin, r_state})
      end
    end]}
  end


end
