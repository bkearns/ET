defmodule ET.Reducers do
  @moduledoc """
  ET.Reducers are a special sort of reduction function which takes and returns
  control-flow information.

  Reducers are expected to accept the following signals:

    :init -> Sent once before other signals, this is a good opportunity to set
             initial state.
    {:cont, state, element} -> This message is sent for each element as long as the
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
      {:cont, [_], elem} ->
        if fun.(elem) do
          {:cont, [true]}
        else
          {:halt, [false]}
        end
      {:fin, [result]} -> {:fin, result}
    end
  end
  def all?(), do: all?(fn x -> x end)

  @doc """
  A reducer which returns false if the function returns false for every element
  received and short-circuits true if it ever returns true.

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
      {:cont, [_], elem} ->
        if fun.(elem) do
          {:halt, [true]}
        else
          {:cont, [false]}
        end
      {:fin, [result]} -> {:fin, result}
    end
  end
  def any?(), do: any?(fn x -> x end)


  @doc """
  A reducer which takes inputs and concats them into a single binary.

  """

  def binary() do
    fn
      :init -> {:cont, [""]}
      {:cont, [acc], elem} -> {:cont, [acc <> to_string(elem)]}
      {:fin, [acc]} -> {:fin, acc}
    end
  end
  def binary(%ET.Transducer{} = trans), do: compose(trans, binary)


  @doc """
  A reducer which counts the number of items recieved.

    iex> ET.reduce(1..3, ET.Reducers.count)
    3

  """

  @spec count(ET.Transducer.t) :: ET.reducer
  @spec count() :: ET.reducer
  def count(%ET.Transducer{} = trans), do: compose(trans, count())
  def count() do
    fn :init                 -> {:cont, [0]}
       {:cont, [acc], _elem} -> {:cont, [acc+1]}
       {:fin, [acc]}         -> {:fin, acc}
    end
  end

    
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
      {:cont, [acc], elem}             -> { :cont, [[elem | acc]] }
      {:fin, [acc]}                    -> { :fin, :lists.reverse(acc) }
    end
  end


  @doc """
  A reducer which accepts tuples in the form of {key, value} and returns
  a Map.

  If fun/2 is provided, it should be of the form:
  (new_value, stored_value -> new_stored_value)

  """

  @spec map() :: ET.reducer
  @spec map(fun) :: ET.reducer
  @spec map(ET.Transducer.t) :: ET.reducer
  @spec map(ET.Transducer.t, fun) :: ET.reducer
  def map() do
    fn
      :init -> {:cont, [%{}]}
      {:cont, [acc], {key, value}} ->
        {:cont, [Dict.put(acc, key, value)]}
      {:fin, [acc]} -> {:fin, acc}
    end
  end
  def map(%ET.Transducer{} = trans), do: compose(trans, map)
  def map(fun) do
    fn
      :init -> {:cont, [%{}]}
      {:cont, [acc], {key, value}} ->
        {:cont, [Dict.update(acc, key, value, &(fun.(&1,value)))]}
      {:fin, [acc]} -> {:fin, acc}
    end
  end
  def map(%ET.Transducer{} = trans, fun), do: compose(trans, map(fun))



  @doc """
  A reducer which returns a fixed value regardless of what it receives.
  The default is :ok.

  """

  def ok(), do: ok(:ok)
  def ok(%ET.Transducer{} = trans), do: compose(trans, ok)
  def ok(t) do
    fn :init              -> {:cont, []}
       {:cont, [], _elem} -> {:cont, []}
       {:fin, []}         -> {:fin, t}
    end
  end
  def ok(%ET.Transducer{} = trans, t), do: compose(trans, ok(t))
end
