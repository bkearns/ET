defmodule ETReducersTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "ET.Reducers.all?()" do
    ET.Reducers.all?
    |> all_test
  end

  test "ET.Reducers.all?(transducer)" do
    identity_trans
    |> ET.Reducers.all?
    |> all_test
  end

  defp all_test (reducer) do
    assert ET.reduce([1, true], reducer) == true
    assert ET.reduce([true, false, true], reducer) == false
    assert ET.reduce([true, nil, true], reducer) == false
  end

  test "ET.Reducers.all?(check_fun)" do
    ET.Reducers.all?(&(&1<4))
    |> all_check_fun_test
  end

  test "ET.Reducers.all?(transducer, check_fun)" do
    identity_trans
    |> ET.Reducers.all?(&(&1<4))
    |> all_check_fun_test
  end

  defp all_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([1,2,3,4], reducer) == false
  end

  test "ET.Reducers.any?()" do
    ET.Reducers.any?
    |> any_test
  end

  test "ET.Reducers.any?(transducer)" do
    identity_trans
    |> ET.Reducers.any?()
    |> any_test
  end

  defp any_test(reducer) do
    assert ET.reduce([false, true], reducer) == true
    assert ET.reduce([false, 1], reducer) == true
    assert ET.reduce([false, nil], reducer) == false
  end

  test "ET.Reducers.any?(check_fun)" do
    ET.Reducers.any?(&(&1<2))
    |> any_check_fun_test
  end

  test "ET.Reducers.any?(transducer, check_fun)" do
    identity_trans
    |> ET.Reducers.any?(&(&1<2))
    |> any_check_fun_test
  end

  defp any_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([2,3,4], reducer) == false
  end

  test "ET.Reducers.binary()" do
    ET.Reducers.binary
    |> binary_test
  end

  test "ET.Reducers.binary(transducer)" do
    identity_trans
    |> ET.Reducers.binary
    |> binary_test
  end

  defp binary_test(reducer) do
    assert ET.reduce(["h", "e", "ll", 0], reducer) ==
           "hell0"
  end

  test "ET.Reducers.count()" do
    ET.Reducers.count
    |> count_test
  end

  test "ET.Reducers.count(transducer)" do
    identity_trans
    |> ET.Reducers.count
    |> count_test
  end

  defp count_test(reducer) do
    assert ET.reduce([], reducer) == 0
    assert ET.reduce(1..3, reducer) == 3
    assert ET.reduce(1..4, reducer) == 4
  end

  test "ET.Reducers.list()" do
    ET.Reducers.list
    |> list_test
  end

  test "ET.Reducers.list(transducer)" do
    identity_trans
    |> ET.Reducers.list
    |> list_test
  end

  defp list_test(reducer) do
    assert ET.reduce([1,2,3,4], reducer) == [1,2,3,4]
  end

  test "ET.Reducers.map()" do
    ET.Reducers.map
    |> map_test
  end

  test "ET.Reducers.map(transducer)" do
    identity_trans
    |> ET.Reducers.map
    |> map_test
  end

  defp map_test(reducer) do
    assert ET.reduce([one: 1, two: 2, one: 3], reducer) ==
    %{one: 3, two: 2}
  end

  test "ET.Reducers.map(fun)" do
    ET.Reducers.map(&(&1+&2))
    |> map_fun_test
  end

  test "ET.Reducers.map(transducer, fun)" do
    identity_trans
    |> ET.Reducers.map(&(&1+&2))
    |> map_fun_test
  end

  defp map_fun_test(adder) do
    assert ET.reduce([one: 1, two: 2, one: 3, two: 4], adder) ==
           %{one: 4, two: 6}
  end

  test "ET.Reducers.ok()" do
    ET.Reducers.ok
    |> ok_test
  end

  test "ET.Reducers.ok(transducer)" do
    identity_trans
    |> ET.Reducers.ok
    |> ok_test
  end

  defp ok_test(reducer) do
    assert ET.reduce(1..5, reducer) == :ok
  end

  test "ET.Reducers.ok(t)" do
    ET.Reducers.ok(:error)
    |> ok_t_test
  end

  test "ET.Reducers.ok(transducer, t)" do
    identity_trans
    |> ET.Reducers.ok(:error)
    |> ok_t_test
  end

  defp ok_t_test(reducer) do
    assert ET.reduce(1..5, reducer) == :error
  end
end
