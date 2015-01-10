defprotocol Transducible do
  def next(collection)
end

defimpl Transducible, for: List do
  def next([elem | rem]), do: {elem, rem}
  def next([]), do: :empty
end
