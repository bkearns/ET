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
    
  def cont(reducer)
  def cont({_, {signal, r_state}}, state), do: {signal, [state | r_state]}


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
  def reduce(elem, {reducer, {:cont, r_state}}) do
    {reducer, reducer.({:cont, r_state, elem})}
  end
end