defmodule TransducibleTest do
  use ExUnit.Case

  test "transducible lists" do
    assert Transducible.next([1,2,3]) == {1, [2,3]}
    assert Transducible.next([]) == :empty
  end
end
