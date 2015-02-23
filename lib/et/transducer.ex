defmodule ET.Transducer do
  defstruct elements: []
  @type t :: %ET.Transducer{elements: list}

  @moduledoc """
  Helper functions and struct for working with transducers.
  """

  @doc """
  Combines two transducers to make a new transducer or one transducer with a
  reducer.

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

    iex> add_one = ET.Transducers.map(&(&1+1))
    iex> ET.Transducer.combine(add_one, ET.Reducers.list)
    iex> ET.reduce(1..3, reducer)
    [2,3,4]

  """

  def compose(%ET.Transducer{elements: t1}, %ET.Transducer{elements: [t2]}) do
    %ET.Transducer{elements: [t2 | t1]}
  end
  def compose(%ET.Transducer{elements: t1}, %ET.Transducer{elements: t2}) do
    %ET.Transducer{elements: t2 ++ t1}
  end

  def compose(%ET.Transducer{elements: [transducer | rest]}, reducer) do
    compose(%ET.Transducer{elements: rest}, transducer.(reducer))
  end
  def compose(%ET.Transducer{elements: []}, reducer), do: reducer


  @doc """
  Extracts the last signal embedded within the reducer.

  """

  def cont(reducer)
  def cont({_, r_signal}), do: r_signal


  @doc """
  Extracts the last signal embedded within the reducer and prepends state to it.

  """

  def cont(reducer, state)
  def cont({_, {signal, r_state}}, state), do: {signal, [state | r_state]}


  @doc """
  Creates a continue signal regardless of the signal below it.

  Used to intercept done signals.

  """

  def cont_no_halt(reducer)
  def cont_no_halt({_, {_, r_state}}), do: {:cont, r_state}


  @doc """
  Creates a continue signal regardless of the signal below it.

  Used to intercept done signals.

  """

  def cont_no_halt(reducer, state)
  def cont_no_halt({_, {_, r_state}}, state), do: {:cont, [state | r_state]}


  @doc """
  Finishes the reducer.

  """

  def finish(reducer)
  def finish({reducer, {_, r_state}}), do: reducer.(r_state, :fin)


  @doc """
  Creates a :halt signal regardless of the reducer's signal.

  """

  def halt(reducer)
  def halt({_, {_, r_state}}), do: {:halt, r_state}


  @doc """
  Creates a :halt signal with state prepended to its state.

  """

  def halt(reducer, state)
  def halt({_, {_, r_state}}, state), do: {:halt, [state | r_state]}


  @doc """
  Returns true if the reducer's signal is :halt and false if it is :cont.

  """

  def halted?(reducer)
  def halted?({_, {:halt, _}}), do: true
  def halted?({_, {:cont, _}}), do: false


  @doc """
  Sends :init to reducing_fun and returns a reducer.

  """

  def init({r_fun, init_term}) do
    {r_fun, r_fun.(init_term, :init)}
  end
  def init(r_fun), do: init({r_fun, nil})


  @doc """
  Builds a new stateless transducer similar to ET.Helpers.new_transducer/2.

  The cont_fun should be in the form of:
  (elem, reducer -> {:cont, state} | {:halt, state})

  """

  def new(cont_fun) do
    %ET.Transducer{elements: [fn r_fun ->
      fn init_term, :init -> r_fun.(init_term, :init)
         r_state, :fin -> r_fun.(r_state, :fin)
         elem, r_state ->
           cont_fun.(elem, {r_fun, {:cont, r_state}})
      end
     end]}
  end
  def new(%ET.Transducer{} = trans, cont_fun) do
    ET.Transducer.compose(trans, new(cont_fun))
  end


  @doc """
  Builds a new transducer from the supplied init, cont, and fin functions.


  The init_fun should be in the form of:
  (reducing_fun -> {:cont, state} | {:halt, state})

  This is often achieved by:
  reducing_fun |> ET.Helpers.init |> ET.Helpers.cont(state)


  The cont_fun should be in the form of:
  (elem, my_state, reducer -> {:cont, state} | {:halt, state})

  ET.Helpers.cont/2 and ET.Helpers.done/2 both aid in this and
  ET.Helpers.reduce/2 transforms a reducer given a new element. this can look
  like:
  elem |> ET.Helpers.reduce(reducer) |> ET.Helpers.cont(state)


  The fin_fun should be in the form of:
  (my_state, reducer -> result)

  ET.Helpers.finish/1 must be called on the reducer unless there is an
  exception.


  Reducers passed to cont_fun and fin_fun are always set to :cont even if this
  transducer has previously received a :halt signal. The transducer must ensure
  that if it transforms a :halt into a :cont or if it has work to do on finish
  that it does not try to reduce elements into a reducer which has returned
  :halt.
  """

  def new(init_fun, cont_fun, fin_fun) do
    %ET.Transducer{elements: [fn r_fun ->
      fn init_term, :init ->
           init_fun.({r_fun, init_term})
         [state | r_state], :fin ->
           fin_fun.({r_fun, {:cont, r_state}}, state)
         elem, [state | r_state] ->
           cont_fun.(elem, {r_fun, {:cont, r_state}}, state)
      end
    end]}
  end
  def new(%ET.Transducer{} = trans, init_fun, cont_fun, fin_fun) do
    ET.Transducer.compose(trans, new(init_fun, cont_fun, fin_fun))
  end


  @doc """
  Continues the reducer with elem returning a reducer.

  """

  def reduce(elem, reducer)
  def reduce(elem, {r_fun, {:cont, r_state}}) do
    {r_fun, r_fun.(elem, r_state)}
  end


  @doc """
  Reduces all elements in transducer until it finishes or reducer returns :halt.
  Return signal is :cont if the transducible finishes.

  """

  def reduce_many(collection, {r_fun, {:cont, r_state}}) do
    case Enumerable.reduce(collection, {:cont, r_state}, r_fun) do
      {:done, r_state} -> {r_fun, {:cont, r_state}}
      {:halted, r_state} -> {r_fun, {:halt, r_state}}
    end
  end


  @doc """
  Reduces the transducible collection into the reducer just once returning
  a continuation and a new reducer.

  """

  def reduce_one(collection, reducer) do
    do_reduce_one(ET.next(collection), reducer)
  end

  defp do_reduce_one({:done, nil}, reducer), do: {:empty, reducer}
  defp do_reduce_one({:suspended, elem, cont_fun}, {r_fun, {:cont, r_state}}) do
    {cont_fun, {r_fun, r_fun.(elem, r_state)}}
  end
end
