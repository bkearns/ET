defmodule ETReducersTest do
  use ExUnit.Case

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "all?()" do
    all_0_test(ET.Reducers.all?)
  end

  test "all?(transducer)" do
    all_0_test(identity_trans |> ET.Reducers.all?)
  end

  defp all_0_test (reducer) do
    assert ET.reduce([1, true], reducer) == true
    assert ET.reduce([true, false, true], reducer) == false
    assert ET.reduce([true, nil, true], reducer) == false
  end

  test "all?(check_fun)" do
    all_1_test(ET.Reducers.all?(&(&1<4)))
  end

  test "all?(transducer, check_fun)" do
    all_1_test(identity_trans |> ET.Reducers.all?(&(&1<4)))
  end

  defp all_1_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([1,2,3,4], reducer) == false
  end

  test "any?" do
    lt_two = ET.Reducers.any?(&(&1<2))
    assert ET.reduce([1,2,3], lt_two) == true
    assert ET.reduce([2,3,4], lt_two) == false
    assert ET.reduce([false, true], ET.Reducers.any?) == true
    assert ET.reduce([false, false], ET.Reducers.any?) == false
  end

  test "count" do
    assert ET.reduce([], ET.Reducers.count) == 0
    assert ET.reduce(1..3, ET.Reducers.count) == 3
    assert ET.reduce(1..4, ET.Reducers.count) == 4
  end
  
  test "list reducer" do
    assert ET.reduce([1,2,3,4], ET.Reducers.list) == [1,2,3,4]
    assert ET.reduce([1,2,3,4], (ET.Transducers.take(2) |> ET.Reducers.list)) == [1,2]
  end
end
