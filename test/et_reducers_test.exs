defmodule ETReducersTest do
  use ExUnit.Case

  test "list reducer" do
    assert ET.reduce([1,2,3,4], ET.Reducers.list) == [1,2,3,4]
    assert ET.reduce([1,2,3,4], (ET.take(2) |> ET.Reducers.list)) == [1,2]
  end
end
