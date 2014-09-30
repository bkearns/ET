defprotocol Transducible do
  def next(collection)
end

defimpl Transducible, for: List do
  def next([]), do: :empty
  def next([h|t]), do: {h, t}
end
