defmodule ET.Transducer do
  defstruct elements: []
  @type t :: %ET.Transducer{elements: list}

  @moduledoc """
  Helper functions and struct for working with transducers.
  """

  @doc """
  Combines two transducers to make a new transducer.

  The shape of two transducers in a chain is the same as a single transducer.
  ET.Transducer.Combine ensures the resulting transducer, when eventually
  composed, will apply the functions left-to-right.

    iex> add_one = ET.Transducers.map(&(&1+1))
    iex> double  = ET.Transducers.map(&(&1*2))
    iex> add_one_then_double = ET.Transducer.combine(add_one, double)
    iex> reducer = ET.compose(add_one_then_double, ET.Reducers.list())
    iex> ET.reduce(1..3, reducer)
    [4,6,8]

  The default transducer and reducer functions all take an optional
  Transducer as their first argument and apply combine automatically,
  so the above could be written as.

    reducer =
         ET.Transducers.map(&(&1+1))
      |> ET.Transducers.map(&(&1*2))
      |> ET.Reducers.list()

    ET.reduce(1..3, reducer)
  """

  @spec combine(ET.Transducer.t, ET.Transducer.t) :: ET.Transducer.t
  def combine(%ET.Transducer{elements: t1}, %ET.Transducer{elements: [t2]}) do
    %ET.Transducer{elements: [t2 | t1]}
  end
  def combine(%ET.Transducer{elements: t1}, %ET.Transducer{elements: t2}) do
    %ET.Transducer{elements: t2 ++ t1}
  end

  @doc """
  Applies a reducer to a transducer, returning a new reducer.

  ET.reduce only takes reducers, so transducers need to be wrapped around an
  existing reducer, producing a new reducer.

    iex> add_one = ET.Transducers.map(&(&1+1))
    iex> ET.Transducer.combine(add_one, ET.Reducers.list)
    iex> ET.reduce(1..3, reducer)
    [2,3,4]
  """

  @spec compose(ET.Transducer.t, ET.reducer) :: ET.reducer
  def compose(%ET.Transducer{elements: [transducer | rest]}, reducer) do
    compose(%ET.Transducer{elements: rest}, transducer.(reducer))
  end
  def compose(%ET.Transducer{elements: []}, reducer), do: reducer

  @doc """
  A helper function for managing state in custom transducers.

  Transducers which use the state object have to prepend their current state every time
  a call comes back up the transducer stack. Prepend state automates this.

    reducer.({:cont, element}) |> ET.prepend_state(new_state)

  """

  @spec prepend_state(ET.return_message, term) :: ET.return_message
  def prepend_state({msg, state}, new_state), do: {msg, [new_state | state]}
end
