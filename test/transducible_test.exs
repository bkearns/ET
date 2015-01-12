defmodule TransducibleTest do
  use ExUnit.Case

  test "transducible lists" do
    assert Transducible.next([1,2,3]) == {1, [2,3]}
    assert Transducible.next([]) == :empty
  end

  test "transducible ranges" do
    assert {1, one} = Transducible.next(1..2)
    assert {2, zero} = Transducible.next(one)
    assert :empty == Transducible.next(zero)
  end

  test "transducible functions" do
    suspend_fun = fn {:cont, _state} -> {:suspended, 1, :fun} end
    assert {1, :fun} == Transducible.next(suspend_fun)
    completed_fun = fn {:cont, _state} -> {:done, nil} end
    assert :empty == Transducible.next(completed_fun)
  end
end
