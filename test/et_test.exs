defmodule ETTest do
  use ExUnit.Case

  test "ET.reduce" do
    inc_reducer = ET.Transducers.map(&(&1+1))
      |> ET.Reducers.list()

    assert ET.reduce([1,2,3], inc_reducer) == [2,3,4]
  end
end
