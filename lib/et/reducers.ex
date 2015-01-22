defmodule ET.Reducers do
  @moduledoc """
  ET.Reducers are a special sort of reduction function which takes and returns
  control-flow information.

  Reducers are expected to accept the following signals:

    :init -> Sent once before other signals, this is a good opportunity to set
             initial state.
    {:cont, input, state} -> This message is sent for each element as long as the
                             reduction is continuing.
    {:fin, state} -> Called as long as there is not an exception. This is an
                     opportunity to close anything that needs closing and indicates
                     that the result should be returned.

  The state object is shared among any transducers and the reducer and is a list.
  A stateful transducer or reducer is allowed one element on this list and must
  remove it before sending a message to the reducer below it so that the next
  stateful function's state is the new head.

  Reducers may return any of the following signals.

    {:cont, state} -> Indicates that the reducer is ready and waiting for a new
                      element.
    {:halt, state} -> Indicates that no more elements should be sent and a :fin
                      signal should come next to finish the reduction.
    {:fin, result} -> Only to be sent after receiving a :fin signal from above.
                      The result is the intended return of the reduce function,
                      although, transducers above this one may replace this.

  This module contains base reducers which might become wrapped with layers of
  transducers. These reducers are intended to build the final result of a
  reduction.

  Named reducer functions should optionally take an %ET.Transducer{} as a first
  argument to aid in pipelining and all of the functions in this module do so.
  """

  @doc """
  A reducer which returns a list of items received in the same order.

    iex> ET.reduce(1..3, ET.Reducers.list)
    [1,2,3]
  """

  @spec list(ET.Transducer.t) :: ET.reducer
  @spec list() :: ET.reducer
  def list(%ET.Transducer{} = trans), do: ET.Transducer.compose(trans, list())
  def list do
    fn
      :init                            -> { :cont, [[]] }
      {:cont, input, [acc]}            -> { :cont, [[input | acc]] }
      {:fin, [acc]}                    -> { :fin, :lists.reverse(acc) }
    end
  end
end