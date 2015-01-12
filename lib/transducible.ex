defprotocol Transducible do
  @fallback_to_any true
  
  def next(collection)
end

defimpl Transducible, for: Any do
  def next(enum) do
    case Enumerable.reduce(enum, {:cont, nil}, fn elem, _ -> {:suspend, elem} end) do
      {:suspended, next_elem, cont_fun} -> {next_elem, cont_fun}
    end
  end
end

defimpl Transducible, for: List do
  def next([elem | rem]), do: {elem, rem}
  def next([]), do: :done
end

defimpl Transducible, for: Function do
  def next(fun) do
    case fun.({:cont, nil}) do
      {:suspended, next_elem, cont_fun} -> {next_elem, cont_fun}
      {:done, nil} -> :done
    end
  end
end
