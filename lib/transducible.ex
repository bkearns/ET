defprotocol Transducible do
  @moduledoc """
  Transducible protocol used by ET.reduce.

  Transducible collections are able to return one item at a time
  along with a continuation.
  """

  @fallback_to_any true

  @typedoc """
  The result of next.

  :done -> indicates that there are no more elements forthcoming.
  {element, continuation} -> the next element along with a
                             transducible continuation

  """

  @type result :: :done | {term, Transducible.t}

  @doc """
  Gets the next element in a collection and a transducible continuation
  or :done if there are no more elements.

  """

  def next(collection)
end

defimpl Transducible, for: Any do
  def next(enum) do
    case Enumerable.reduce(enum, {:cont, nil}, fn elem, _ -> {:suspend, elem} end) do
      {:suspended, next_elem, cont_fun} -> {next_elem, cont_fun}
      {:done, nil} -> :done
    end
  end
end

defimpl Transducible, for: List do
  def next([elem | rem]), do: {elem, rem}
  def next([]), do: :done
end

defimpl Transducible, for: Function do
  def next(fun) when is_function(fun, 2) do
    case Enumerable.reduce(fun, {:cont, nil}, fn elem, _ -> {:suspend, elem} end) do
      {:suspended, next_elem, cont_fun} -> {next_elem, cont_fun}
      {:done, nil} -> :done
    end
  end
  def next(fun) when is_function(fun, 1) do
    case fun.({:cont, nil}) do
      {:suspended, next_elem, cont_fun} -> {next_elem, cont_fun}
      {:done, nil} -> :done
    end
  end
end
