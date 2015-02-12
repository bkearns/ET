defmodule ET.Helpers do
  @moduledoc """
  Provides helper functions for building transducers.

  """

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

  Used to intercept halt signals.

  """

  def cont_nohalt(reducer)
  def cont_nohalt({_, {_, r_state}}), do: {:cont, r_state}


  @doc """
  Creates a continue signal regardless of the signal below it.

  Used to intercept halt signals.

  """

  def cont_nohalt(reducer, state)
  def cont_nohalt({_, {_, r_state}}, state), do: {:cont, [state | r_state]}

  @doc """
  Finishes the reducer.

  """

  def finish(reducer)
  def finish({reducer, {_, r_state}}), do: reducer.({:fin, r_state})


  @doc """
  Creates a :halt signal regardless of the reducer's signal.

  """

  def halt(reducer)
  def halt({_, {_, r_state}}), do: {:halt, r_state}


  @doc """
  Returns true if the reducer's signal is :halt and false if it is :cont.

  """

  def halted?(reducer)
  def halted?({_, {:halt, _}}), do: true
  def halted?({_, {:cont, _}}), do: false


  @doc """
  Creates a :halt signal with state prepended to it.

  """

  def halt(reducer, state)
  def halt({_, {_, r_state}}, state), do: {:halt, [state | r_state]}


  @doc """
  Sends :init to reducing_fun and returns a reducer.

  """

  def init(reducing_fun), do: {reducing_fun, reducing_fun.(:init)}


  @doc """
  Builds a new stateless transducer similar to ET.Helpers.new_transducer/2.

  The cont_fun should be in the form of:
  (elem, reducer -> {:cont, state} | {:halt, state})

  """

  def new_transducer(cont_fun) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init -> reducer.(:init)
         {:cont, r_state, elem} ->
           cont_fun.(elem, {reducer, {:cont, r_state}})
         {:fin, r_state} -> reducer.({:fin, r_state})
      end
     end]}
  end
  def new_transducer(%ET.Transducer{} = trans, cont_fun) do
    ET.Transducer.compose(trans, new_transducer(cont_fun))
  end

  @doc """
  Builds a new transducer from the supplied init, cont, and fin functions.


  The init_fun should be in the form of:
  (reducing_fun -> {:cont, state} | {:halt, state})

  This is often achieved by:
  reducing_fun |> ET.Helpers.init |> ET.Helpers.cont(state)


  The cont_fun should be in the form of:
  (elem, my_state, reducer -> {:cont, state} | {:halt, state})

  ET.Helpers.cont/2 and ET.Helpers.halt/2 both aid in this and
  ET.Helpers.reduce/2 transforms a reducer given a new element. this can look like:
  elem |> ET.Helpers.reduce(reducer) |> ET.Helpers.cont(state)


  The fin_fun should be in the form of:
  (my_state, reducer -> {:fin, result})

  ET.Helpers.finish/1 must be called on the reducer unless there is an exception.


  Reducers passed to cont_fun and fin_fun are always set to :cont even if this
  transducer has previously received a :halt signal. The transducer must ensure
  that if it transforms a :halt into a :cont or if it has work to do on finish
  that it does not try to reduce elements into a reducer which has :halt-ed.
  """

  def new_transducer(init_fun, cont_fun, fin_fun) do
    %ET.Transducer{elements: [fn reducer ->
      fn :init ->
           init_fun.(reducer)
         {:cont, [state | r_state], elem} ->
           cont_fun.(elem, state, {reducer, {:cont, r_state}})
         {:fin, [state | r_state]} ->
           fin_fun.(state, {reducer, {:cont, r_state}})
      end
    end]}
  end
  def new_transducer(%ET.Transducer{} = trans, init_fun, cont_fun, fin_fun) do
    ET.Transducer.compose(trans, new_transducer(init_fun, cont_fun, fin_fun))
  end


  @doc """
  Continues the reducer with elem returning a reducer.

  """

  def reduce(elem, reducer)
  def reduce(elem, {r_fun, {:cont, r_state}}) do
    {r_fun, r_fun.({:cont, r_state, elem})}
  end


  @doc """
  Reduces all elements in transducer until it finishes or reducer returns :halt.

  """

  def reduce_many(transducible, reducer)
  def reduce_many(transducible, {r_fun, {:cont, _} = r_signal}) do
    case ET.reduce_elements(transducible, r_signal, r_fun) do
      {:halt, r_state, _} -> {r_fun, {:halt, r_state}}
      {:done, r_state, _} -> {r_fun, {:cont, r_state}}
    end
  end


  @doc """
  Reduces the transducible collection into the reducer just once returning
  a continuation and a new reducer.

  """

  def reduce_one(transducible, reducer)
  def reduce_one(transducible, {r_fun, {:cont, r_state}}) do
    case ET.reduce_step(transducible, r_state, r_fun) do
      {{:done, r_state}, continuation} -> {:done, {r_fun, {:cont, r_state}}}
      {{sig, r_state}, continuation} -> {continuation, {r_fun, {sig, r_state}}}
    end
  end
end
