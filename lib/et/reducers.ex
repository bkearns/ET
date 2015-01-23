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

  import ET.Transducer, only: [compose: 2]

  @doc """
  A reducer which returns true if the function returns true for every element
  received and short-circuits false if it ever returns false.

    iex> ET.reduce([1,2,3], ET.Reducers.all?(&(&1<4)))
    true

    iex> ET.reduce([1,2,3,4], ET.Reducers.all?(&(&1<4)))
    false

  """

  @spec all?(ET.Transducer.t, (term -> boolean)) :: ET.reducer
  @spec all?((term -> boolean)) :: ET.reducer
  @spec all?(ET.Transducer.t) :: ET.reducer
  @spec all?() :: ET.reducer
  def all?(%ET.Transducer{} = trans, fun), do: compose(trans, all?(fun))
  def all?(%ET.Transducer{} = trans), do: all?(trans, fn x -> x end)
  def all?(fun) do
    fn
      :init -> {:cont, [true]}
      {:cont, input, [_]} ->
        if fun.(input) do
          {:cont, [true]}
        else
          {:halt, [false]}
        end
      {:fin, [result]} -> {:fin, result}
    end
  end
  def all?(), do: all?(fn x -> x end)

  @doc """
  A reducer which returns true if the function returns true for every element
  received and short-circuits false if it ever returns false.

    iex> ET.reduce([1,2,3], ET.Reducers.any?(&(&1<2)))
    true

    iex> ET.reduce([2,3,4], ET.Reducers.any?(&(&1<2)))
    false

  """
  
  @spec any?(ET.Transducer.t, (term -> boolean)) :: ET.reducer
  @spec any?((term -> boolean)) :: ET.reducer
  @spec any?(ET.Transducer.t) :: ET.reducer
  @spec any?() :: ET.reducer
  def any?(%ET.Transducer{} = trans, fun), do: compose(trans, any?(fun))
  def any?(%ET.Transducer{} = trans), do: any?(trans, fn x -> x end)
  def any?(fun) do
    fn
      :init -> {:cont, [false]}
      {:cont, input, [_]} ->
        if fun.(input) do
          {:halt, [true]}
        else
          {:cont, [false]}
        end
      {:fin, [result]} -> {:fin, result}
    end
  end
  def any?(), do: any?(fn x -> x end)

  @doc """
  A reducer which returns a list of items received in the same order.

    iex> ET.reduce(1..3, ET.Reducers.list)
    [1,2,3]
  """

  @spec list(ET.Transducer.t) :: ET.reducer
  @spec list() :: ET.reducer
  def list(%ET.Transducer{} = trans), do: compose(trans, list())
  def list do
    fn
      :init                            -> { :cont, [[]] }
      {:cont, input, [acc]}            -> { :cont, [[input | acc]] }
      {:fin, [acc]}                    -> { :fin, :lists.reverse(acc) }
    end
  end
end
