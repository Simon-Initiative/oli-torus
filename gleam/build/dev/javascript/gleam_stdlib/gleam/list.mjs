/// <reference types="./list.d.mts" />
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  divideFloat,
  isEqual,
} from "../gleam.mjs";
import * as $dict from "../gleam/dict.mjs";
import * as $float from "../gleam/float.mjs";
import * as $int from "../gleam/int.mjs";
import * as $order from "../gleam/order.mjs";

const FILEPATH = "src/gleam/list.gleam";

export class Continue extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ContinueOrStop$Continue = ($0) => new Continue($0);
export const ContinueOrStop$isContinue = (value) => value instanceof Continue;
export const ContinueOrStop$Continue$0 = (value) => value[0];

export class Stop extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ContinueOrStop$Stop = ($0) => new Stop($0);
export const ContinueOrStop$isStop = (value) => value instanceof Stop;
export const ContinueOrStop$Stop$0 = (value) => value[0];

class Ascending extends $CustomType {}

class Descending extends $CustomType {}

const min_positive = 2.2250738585072014e-308;

function length_loop(loop$list, loop$count) {
  while (true) {
    let list = loop$list;
    let count = loop$count;
    if (list instanceof $Empty) {
      return count;
    } else {
      let list$1 = list.tail;
      loop$list = list$1;
      loop$count = count + 1;
    }
  }
}

/**
 * Counts the number of elements in a given list.
 *
 * This function has to traverse the list to determine the number of elements,
 * so it runs in linear time.
 *
 * This function is natively implemented by the virtual machine and is highly
 * optimised.
 *
 * ## Examples
 *
 * ```gleam
 * assert length([]) == 0
 * ```
 *
 * ```gleam
 * assert length([1]) == 1
 * ```
 *
 * ```gleam
 * assert length([1, 2]) == 2
 * ```
 */
export function length(list) {
  return length_loop(list, 0);
}

function count_loop(loop$list, loop$predicate, loop$acc) {
  while (true) {
    let list = loop$list;
    let predicate = loop$predicate;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return acc;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = predicate(first$1);
      if ($) {
        loop$list = rest$1;
        loop$predicate = predicate;
        loop$acc = acc + 1;
      } else {
        loop$list = rest$1;
        loop$predicate = predicate;
        loop$acc = acc;
      }
    }
  }
}

/**
 * Counts the number of elements in a given list satisfying a given predicate.
 *
 * This function has to traverse the list to determine the number of elements,
 * so it runs in linear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert count([], fn(a) { a > 0 }) == 0
 * ```
 *
 * ```gleam
 * assert count([1], fn(a) { a > 0 }) == 1
 * ```
 *
 * ```gleam
 * assert count([1, 2, 3], int.is_odd) == 2
 * ```
 */
export function count(list, predicate) {
  return count_loop(list, predicate, 0);
}

/**
 * Reverses a list and prepends it to another list.
 * This function runs in linear time, proportional to the length of the list
 * to prepend.
 * 
 * @ignore
 */
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix instanceof $Empty) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = listPrepend(first$1, suffix);
    }
  }
}

/**
 * Creates a new list from a given list containing the same elements but in the
 * opposite order.
 *
 * This function has to traverse the list to create the new reversed list, so
 * it runs in linear time.
 *
 * This function is natively implemented by the virtual machine and is highly
 * optimised.
 *
 * ## Examples
 *
 * ```gleam
 * assert reverse([]) == []
 * ```
 *
 * ```gleam
 * assert reverse([1]) == [1]
 * ```
 *
 * ```gleam
 * assert reverse([1, 2]) == [2, 1]
 * ```
 */
export function reverse(list) {
  return reverse_and_prepend(list, toList([]));
}

/**
 * Determines whether or not the list is empty.
 *
 * This function runs in constant time.
 *
 * ## Examples
 *
 * ```gleam
 * assert is_empty([])
 * ```
 *
 * ```gleam
 * assert !is_empty([1])
 * ```
 *
 * ```gleam
 * assert !is_empty([1, 1])
 * ```
 */
export function is_empty(list) {
  return isEqual(list, toList([]));
}

/**
 * Determines whether or not a given element exists within a given list.
 *
 * This function traverses the list to find the element, so it runs in linear
 * time.
 *
 * ## Examples
 *
 * ```gleam
 * assert !contains([], any: 0)
 * ```
 *
 * ```gleam
 * assert [0] |> contains(any: 0)
 * ```
 *
 * ```gleam
 * assert !contains([1], any: 0)
 * ```
 *
 * ```gleam
 * assert !contains([1, 1], any: 0)
 * ```
 *
 * ```gleam
 * assert [1, 0] |> contains(any: 0)
 * ```
 */
export function contains(loop$list, loop$elem) {
  while (true) {
    let list = loop$list;
    let elem = loop$elem;
    if (list instanceof $Empty) {
      return false;
    } else {
      let first$1 = list.head;
      if (isEqual(first$1, elem)) {
        return true;
      } else {
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$elem = elem;
      }
    }
  }
}

/**
 * Gets the first element from the start of the list, if there is one.
 *
 * ## Examples
 *
 * ```gleam
 * assert first([]) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert first([0]) == Ok(0)
 * ```
 *
 * ```gleam
 * assert first([1, 2]) == Ok(1)
 * ```
 */
export function first(list) {
  if (list instanceof $Empty) {
    return new Error(undefined);
  } else {
    let first$1 = list.head;
    return new Ok(first$1);
  }
}

/**
 * Returns the list minus the first element. If the list is empty, `Error(Nil)` is
 * returned.
 *
 * This function runs in constant time and does not make a copy of the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert rest([]) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert rest([0]) == Ok([])
 * ```
 *
 * ```gleam
 * assert rest([1, 2]) == Ok([2])
 * ```
 */
export function rest(list) {
  if (list instanceof $Empty) {
    return new Error(undefined);
  } else {
    let rest$1 = list.tail;
    return new Ok(rest$1);
  }
}

/**
 * Groups the elements from the given list by the given key function.
 *
 * Does not preserve the initial value order.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/dict
 *
 * assert
 *   [Ok(3), Error("Wrong"), Ok(200), Ok(73)]
 *   |> group(by: fn(i) {
 *     case i {
 *       Ok(_) -> "Successful"
 *       Error(_) -> "Failed"
 *     }
 *   })
 *   |> dict.to_list
 *   == [
 *     #("Failed", [Error("Wrong")]),
 *     #("Successful", [Ok(73), Ok(200), Ok(3)])
 *   ]
 * ```
 *
 * ```gleam
 * import gleam/dict
 *
 * assert group([1,2,3,4,5], by: fn(i) { i - i / 3 * 3 })
 *   |> dict.to_list
 *   == [#(0, [3]), #(1, [4, 1]), #(2, [5, 2])]
 * ```
 */
export function group(list, key) {
  return $dict.group(key, list);
}

function filter_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let _block;
      let $ = fun(first$1);
      if ($) {
        _block = listPrepend(first$1, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}

/**
 * Returns a new list containing only the elements from the first list for
 * which the given functions returns `True`.
 *
 * ## Examples
 *
 * ```gleam
 * assert filter([2, 4, 6, 1], fn(x) { x > 2 }) == [4, 6]
 * ```
 *
 * ```gleam
 * assert filter([2, 4, 6, 1], fn(x) { x > 6 }) == []
 * ```
 */
export function filter(list, predicate) {
  return filter_loop(list, predicate, toList([]));
}

function filter_map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let _block;
      let $ = fun(first$1);
      if ($ instanceof Ok) {
        let first$2 = $[0];
        _block = listPrepend(first$2, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}

/**
 * Returns a new list containing only the elements from the first list for
 * which the given functions returns `Ok(_)`.
 *
 * ## Examples
 *
 * ```gleam
 * assert filter_map([2, 4, 6, 1], Error) == []
 * ```
 *
 * ```gleam
 * assert filter_map([2, 4, 6, 1], fn(x) { Ok(x + 1) }) == [3, 5, 7, 2]
 * ```
 */
export function filter_map(list, fun) {
  return filter_map_loop(list, fun, toList([]));
}

function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = listPrepend(fun(first$1), acc);
    }
  }
}

/**
 * Returns a new list containing the results of applying the supplied function to each element.
 *
 * ## Examples
 *
 * ```gleam
 * assert map([2, 4, 6], fn(x) { x * 2 }) == [4, 8, 12]
 * ```
 */
export function map(list, fun) {
  return map_loop(list, fun, toList([]));
}

function map2_loop(loop$list1, loop$list2, loop$fun, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list2 = loop$list2;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list1 instanceof $Empty) {
      return reverse(acc);
    } else if (list2 instanceof $Empty) {
      return reverse(acc);
    } else {
      let a = list1.head;
      let as_ = list1.tail;
      let b = list2.head;
      let bs = list2.tail;
      loop$list1 = as_;
      loop$list2 = bs;
      loop$fun = fun;
      loop$acc = listPrepend(fun(a, b), acc);
    }
  }
}

/**
 * Combines two lists into a single list using the given function.
 *
 * If a list is longer than the other, the extra elements are dropped.
 *
 * ## Examples
 *
 * ```gleam
 * assert map2([1, 2, 3], [4, 5, 6], fn(x, y) { x + y }) == [5, 7, 9]
 * ```
 *
 * ```gleam
 * assert map2([1, 2], ["a", "b", "c"], fn(i, x) { #(i, x) })
 *   == [#(1, "a"), #(2, "b")]
 * ```
 */
export function map2(list1, list2, fun) {
  return map2_loop(list1, list2, fun, toList([]));
}

function map_fold_loop(loop$list, loop$fun, loop$acc, loop$list_acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    let list_acc = loop$list_acc;
    if (list instanceof $Empty) {
      return [acc, reverse(list_acc)];
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = fun(acc, first$1);
      let acc$1;
      let first$2;
      acc$1 = $[0];
      first$2 = $[1];
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = acc$1;
      loop$list_acc = listPrepend(first$2, list_acc);
    }
  }
}

/**
 * Similar to `map` but also lets you pass around an accumulated value.
 *
 * ## Examples
 *
 * ```gleam
 * assert
 *   map_fold(
 *     over: [1, 2, 3],
 *     from: 100,
 *     with: fn(memo, i) { #(memo + i, i * 2) }
 *   )
 *   == #(106, [2, 4, 6])
 * ```
 */
export function map_fold(list, initial, fun) {
  return map_fold_loop(list, fun, initial, toList([]));
}

function index_map_loop(loop$list, loop$fun, loop$index, loop$acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let index = loop$index;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let acc$1 = listPrepend(fun(first$1, index), acc);
      loop$list = rest$1;
      loop$fun = fun;
      loop$index = index + 1;
      loop$acc = acc$1;
    }
  }
}

/**
 * Similar to `map`, but the supplied function will also be passed the index
 * of the element being mapped as an additional argument.
 *
 * The index starts at 0, so the first element is 0, the second is 1, and so
 * on.
 *
 * ## Examples
 *
 * ```gleam
 * assert index_map(["a", "b"], fn(x, i) { #(i, x) }) == [#(0, "a"), #(1, "b")]
 * ```
 */
export function index_map(list, fun) {
  return index_map_loop(list, fun, 0, toList([]));
}

function try_map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return new Ok(reverse(acc));
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = fun(first$1);
      if ($ instanceof Ok) {
        let first$2 = $[0];
        loop$list = rest$1;
        loop$fun = fun;
        loop$acc = listPrepend(first$2, acc);
      } else {
        return $;
      }
    }
  }
}

/**
 * Takes a function that returns a `Result` and applies it to each element in a
 * given list in turn.
 *
 * If the function returns `Ok(new_value)` for all elements in the list then a
 * list of the new values is returned.
 *
 * If the function returns `Error(reason)` for any of the elements then it is
 * returned immediately. None of the elements in the list are processed after
 * one returns an `Error`.
 *
 * ## Examples
 *
 * ```gleam
 * assert try_map([1, 2, 3], fn(x) { Ok(x + 2) }) == Ok([3, 4, 5])
 * ```
 *
 * ```gleam
 * assert try_map([1, 2, 3], fn(_) { Error(0) }) == Error(0)
 * ```
 *
 * ```gleam
 * assert try_map([[1], [2, 3]], first) == Ok([1, 2])
 * ```
 *
 * ```gleam
 * assert try_map([[1], [], [2]], first) == Error(Nil)
 * ```
 */
export function try_map(list, fun) {
  return try_map_loop(list, fun, toList([]));
}

/**
 * Returns a list that is the given list with up to the given number of
 * elements removed from the front of the list.
 *
 * If the list has less than the number of elements an empty list is
 * returned.
 *
 * This function runs in linear time but does not copy the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert drop([1, 2, 3, 4], 2) == [3, 4]
 * ```
 *
 * ```gleam
 * assert drop([1, 2, 3, 4], 9) == []
 * ```
 */
export function drop(loop$list, loop$n) {
  while (true) {
    let list = loop$list;
    let n = loop$n;
    let $ = n <= 0;
    if ($) {
      return list;
    } else {
      if (list instanceof $Empty) {
        return list;
      } else {
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$n = n - 1;
      }
    }
  }
}

function take_loop(loop$list, loop$n, loop$acc) {
  while (true) {
    let list = loop$list;
    let n = loop$n;
    let acc = loop$acc;
    let $ = n <= 0;
    if ($) {
      return reverse(acc);
    } else {
      if (list instanceof $Empty) {
        return reverse(acc);
      } else {
        let first$1 = list.head;
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$n = n - 1;
        loop$acc = listPrepend(first$1, acc);
      }
    }
  }
}

/**
 * Returns a list containing the first given number of elements from the given
 * list.
 *
 * If the list has less than the number of elements then the full list is
 * returned.
 *
 * This function runs in linear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert take([1, 2, 3, 4], 2) == [1, 2]
 * ```
 *
 * ```gleam
 * assert take([1, 2, 3, 4], 9) == [1, 2, 3, 4]
 * ```
 */
export function take(list, n) {
  return take_loop(list, n, toList([]));
}

/**
 * Returns a new empty list.
 *
 * ## Examples
 *
 * ```gleam
 * assert new() == []
 * ```
 */
export function new$() {
  return toList([]);
}

/**
 * Returns the given item wrapped in a list.
 *
 * ## Examples
 *
 * ```gleam
 * assert wrap(1) == [1]
 * ```
 *
 * ```gleam
 * assert wrap(["a", "b", "c"]) == [["a", "b", "c"]]
 * ```
 *
 * ```gleam
 * assert wrap([[]]) == [[[]]]
 * ```
 */
export function wrap(item) {
  return toList([item]);
}

function append_loop(loop$first, loop$second) {
  while (true) {
    let first = loop$first;
    let second = loop$second;
    if (first instanceof $Empty) {
      return second;
    } else {
      let first$1 = first.head;
      let rest$1 = first.tail;
      loop$first = rest$1;
      loop$second = listPrepend(first$1, second);
    }
  }
}

/**
 * Joins one list onto the end of another.
 *
 * This function runs in linear time, and it traverses and copies the first
 * list.
 *
 * ## Examples
 *
 * ```gleam
 * assert append([1, 2], [3]) == [1, 2, 3]
 * ```
 */
export function append(first, second) {
  return append_loop(reverse(first), second);
}

/**
 * Prefixes an item to a list. This can also be done using the dedicated
 * syntax instead.
 *
 * ```gleam
 * let existing_list = [2, 3, 4]
 * assert [1, ..existing_list] == [1, 2, 3, 4]
 * ```
 *
 * ```gleam
 * let existing_list = [2, 3, 4]
 * assert prepend(to: existing_list, this: 1) == [1, 2, 3, 4]
 * ```
 */
export function prepend(list, item) {
  return listPrepend(item, list);
}

function flatten_loop(loop$lists, loop$acc) {
  while (true) {
    let lists = loop$lists;
    let acc = loop$acc;
    if (lists instanceof $Empty) {
      return reverse(acc);
    } else {
      let list = lists.head;
      let further_lists = lists.tail;
      loop$lists = further_lists;
      loop$acc = reverse_and_prepend(list, acc);
    }
  }
}

/**
 * Joins a list of lists into a single list.
 *
 * This function traverses all elements twice on the JavaScript target.
 * This function traverses all elements once on the Erlang target.
 *
 * ## Examples
 *
 * ```gleam
 * assert flatten([[1], [2, 3], []]) == [1, 2, 3]
 * ```
 */
export function flatten(lists) {
  return flatten_loop(lists, toList([]));
}

/**
 * Maps the list with the given function into a list of lists, and then flattens it.
 *
 * ## Examples
 *
 * ```gleam
 * assert flat_map([2, 4, 6], fn(x) { [x, x + 1] }) == [2, 3, 4, 5, 6, 7]
 * ```
 */
export function flat_map(list, fun) {
  return flatten(map(list, fun));
}

/**
 * Reduces a list of elements into a single value by calling a given function
 * on each element, going from left to right.
 *
 * `fold([1, 2, 3], 0, add)` is the equivalent of
 * `add(add(add(0, 1), 2), 3)`.
 *
 * This function runs in linear time.
 */
export function fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list instanceof $Empty) {
      return initial;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, first$1);
      loop$fun = fun;
    }
  }
}

/**
 * Reduces a list of elements into a single value by calling a given function
 * on each element, going from right to left.
 *
 * `fold_right([1, 2, 3], 0, add)` is the equivalent of
 * `add(add(add(0, 3), 2), 1)`.
 *
 * This function runs in linear time.
 *
 * Unlike `fold` this function is not tail recursive. Where possible use
 * `fold` instead as it will use less memory.
 */
export function fold_right(list, initial, fun) {
  if (list instanceof $Empty) {
    return initial;
  } else {
    let first$1 = list.head;
    let rest$1 = list.tail;
    return fun(fold_right(rest$1, initial, fun), first$1);
  }
}

function index_fold_loop(loop$over, loop$acc, loop$with, loop$index) {
  while (true) {
    let over = loop$over;
    let acc = loop$acc;
    let with$ = loop$with;
    let index = loop$index;
    if (over instanceof $Empty) {
      return acc;
    } else {
      let first$1 = over.head;
      let rest$1 = over.tail;
      loop$over = rest$1;
      loop$acc = with$(acc, first$1, index);
      loop$with = with$;
      loop$index = index + 1;
    }
  }
}

/**
 * Like `fold` but the folding function also receives the index of the current element.
 *
 * ## Examples
 *
 * ```gleam
 * assert ["a", "b", "c"]
 *   |> index_fold("", fn(acc, item, index) {
 *     acc <> int.to_string(index) <> ":" <> item <> " "
 *   })
 *   == "0:a 1:b 2:c"
 * ```
 *
 * ```gleam
 * assert [10, 20, 30]
 *   |> index_fold(0, fn(acc, item, index) { acc + item * index })
 *   == 80
 * ```
 */
export function index_fold(list, initial, fun) {
  return index_fold_loop(list, initial, fun, 0);
}

/**
 * A variant of fold that might fail.
 *
 * The folding function should return `Result(accumulator, error)`.
 * If the returned value is `Ok(accumulator)` try_fold will try the next value in the list.
 * If the returned value is `Error(error)` try_fold will stop and return that error.
 *
 * ## Examples
 *
 * ```gleam
 * assert [1, 2, 3, 4]
 *   |> try_fold(0, fn(acc, i) {
 *     case i < 3 {
 *       True -> Ok(acc + i)
 *       False -> Error(Nil)
 *     }
 *   })
 *   == Error(Nil)
 * ```
 */
export function try_fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list instanceof $Empty) {
      return new Ok(initial);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = fun(initial, first$1);
      if ($ instanceof Ok) {
        let result = $[0];
        loop$list = rest$1;
        loop$initial = result;
        loop$fun = fun;
      } else {
        return $;
      }
    }
  }
}

/**
 * A variant of fold that allows to stop folding earlier.
 *
 * The folding function should return `ContinueOrStop(accumulator)`.
 * If the returned value is `Continue(accumulator)` fold_until will try the next value in the list.
 * If the returned value is `Stop(accumulator)` fold_until will stop and return that accumulator.
 *
 * ## Examples
 *
 * ```gleam
 * assert [1, 2, 3, 4]
 *   |> fold_until(0, fn(acc, i) {
 *     case i < 3 {
 *       True -> Continue(acc + i)
 *       False -> Stop(acc)
 *     }
 *   })
 *   == 3
 * ```
 */
export function fold_until(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list instanceof $Empty) {
      return initial;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = fun(initial, first$1);
      if ($ instanceof Continue) {
        let next_accumulator = $[0];
        loop$list = rest$1;
        loop$initial = next_accumulator;
        loop$fun = fun;
      } else {
        let b = $[0];
        return b;
      }
    }
  }
}

/**
 * Finds the first element in a given list for which the given function returns
 * `True`.
 *
 * Returns `Error(Nil)` if no such element is found.
 *
 * ## Examples
 *
 * ```gleam
 * assert find([1, 2, 3], fn(x) { x > 2 }) == Ok(3)
 * ```
 *
 * ```gleam
 * assert find([1, 2, 3], fn(x) { x > 4 }) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert find([], fn(_) { True }) == Error(Nil)
 * ```
 */
export function find(loop$list, loop$is_desired) {
  while (true) {
    let list = loop$list;
    let is_desired = loop$is_desired;
    if (list instanceof $Empty) {
      return new Error(undefined);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = is_desired(first$1);
      if ($) {
        return new Ok(first$1);
      } else {
        loop$list = rest$1;
        loop$is_desired = is_desired;
      }
    }
  }
}

/**
 * Finds the first element in a given list for which the given function returns
 * `Ok(new_value)`, then returns the wrapped `new_value`.
 *
 * Returns `Error(Nil)` if no such element is found.
 *
 * ## Examples
 *
 * ```gleam
 * assert find_map([[], [2], [3]], first) == Ok(2)
 * ```
 *
 * ```gleam
 * assert find_map([[], []], first) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert find_map([], first) == Error(Nil)
 * ```
 */
export function find_map(loop$list, loop$fun) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    if (list instanceof $Empty) {
      return new Error(undefined);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = fun(first$1);
      if ($ instanceof Ok) {
        return $;
      } else {
        loop$list = rest$1;
        loop$fun = fun;
      }
    }
  }
}

/**
 * Returns `True` if the given function returns `True` for all the elements in
 * the given list. If the function returns `False` for any of the elements it
 * immediately returns `False` without checking the rest of the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert all([], fn(x) { x > 3 })
 * ```
 *
 * ```gleam
 * assert all([4, 5], fn(x) { x > 3 })
 * ```
 *
 * ```gleam
 * assert !all([4, 3], fn(x) { x > 3 })
 * ```
 */
export function all(loop$list, loop$predicate) {
  while (true) {
    let list = loop$list;
    let predicate = loop$predicate;
    if (list instanceof $Empty) {
      return true;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = predicate(first$1);
      if ($) {
        loop$list = rest$1;
        loop$predicate = predicate;
      } else {
        return $;
      }
    }
  }
}

/**
 * Returns `True` if the given function returns `True` for any the elements in
 * the given list. If the function returns `True` for any of the elements it
 * immediately returns `True` without checking the rest of the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert !any([], fn(x) { x > 3 })
 * ```
 *
 * ```gleam
 * assert any([4, 5], fn(x) { x > 3 })
 * ```
 *
 * ```gleam
 * assert any([4, 3], fn(x) { x > 4 })
 * ```
 *
 * ```gleam
 * assert any([3, 4], fn(x) { x > 3 })
 * ```
 */
export function any(loop$list, loop$predicate) {
  while (true) {
    let list = loop$list;
    let predicate = loop$predicate;
    if (list instanceof $Empty) {
      return false;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = predicate(first$1);
      if ($) {
        return $;
      } else {
        loop$list = rest$1;
        loop$predicate = predicate;
      }
    }
  }
}

function zip_loop(loop$one, loop$other, loop$acc) {
  while (true) {
    let one = loop$one;
    let other = loop$other;
    let acc = loop$acc;
    if (one instanceof $Empty) {
      return reverse(acc);
    } else if (other instanceof $Empty) {
      return reverse(acc);
    } else {
      let first_one = one.head;
      let rest_one = one.tail;
      let first_other = other.head;
      let rest_other = other.tail;
      loop$one = rest_one;
      loop$other = rest_other;
      loop$acc = listPrepend([first_one, first_other], acc);
    }
  }
}

/**
 * Takes two lists and returns a single list of 2-element tuples.
 *
 * If one of the lists is longer than the other, the remaining elements from
 * the longer list are not used.
 *
 * ## Examples
 *
 * ```gleam
 * assert zip([], []) == []
 * ```
 *
 * ```gleam
 * assert zip([1, 2], [3]) == [#(1, 3)]
 * ```
 *
 * ```gleam
 * assert zip([1], [3, 4]) == [#(1, 3)]
 * ```
 *
 * ```gleam
 * assert zip([1, 2], [3, 4]) == [#(1, 3), #(2, 4)]
 * ```
 */
export function zip(list, other) {
  return zip_loop(list, other, toList([]));
}

function strict_zip_loop(loop$one, loop$other, loop$acc) {
  while (true) {
    let one = loop$one;
    let other = loop$other;
    let acc = loop$acc;
    if (one instanceof $Empty) {
      if (other instanceof $Empty) {
        return new Ok(reverse(acc));
      } else {
        return new Error(undefined);
      }
    } else if (other instanceof $Empty) {
      return new Error(undefined);
    } else {
      let first_one = one.head;
      let rest_one = one.tail;
      let first_other = other.head;
      let rest_other = other.tail;
      loop$one = rest_one;
      loop$other = rest_other;
      loop$acc = listPrepend([first_one, first_other], acc);
    }
  }
}

/**
 * Takes two lists and returns a single list of 2-element tuples.
 *
 * If one of the lists is longer than the other, an `Error` is returned.
 *
 * ## Examples
 *
 * ```gleam
 * assert strict_zip([], []) == Ok([])
 * ```
 *
 * ```gleam
 * assert strict_zip([1, 2], [3]) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert strict_zip([1], [3, 4]) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert strict_zip([1, 2], [3, 4]) == Ok([#(1, 3), #(2, 4)])
 * ```
 */
export function strict_zip(list, other) {
  return strict_zip_loop(list, other, toList([]));
}

function unzip_loop(loop$input, loop$one, loop$other) {
  while (true) {
    let input = loop$input;
    let one = loop$one;
    let other = loop$other;
    if (input instanceof $Empty) {
      return [reverse(one), reverse(other)];
    } else {
      let rest$1 = input.tail;
      let first_one = input.head[0];
      let first_other = input.head[1];
      loop$input = rest$1;
      loop$one = listPrepend(first_one, one);
      loop$other = listPrepend(first_other, other);
    }
  }
}

/**
 * Takes a single list of 2-element tuples and returns two lists.
 *
 * ## Examples
 *
 * ```gleam
 * assert unzip([#(1, 2), #(3, 4)]) == #([1, 3], [2, 4])
 * ```
 *
 * ```gleam
 * assert unzip([]) == #([], [])
 * ```
 */
export function unzip(input) {
  return unzip_loop(input, toList([]), toList([]));
}

function intersperse_loop(loop$list, loop$separator, loop$acc) {
  while (true) {
    let list = loop$list;
    let separator = loop$separator;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      loop$list = rest$1;
      loop$separator = separator;
      loop$acc = listPrepend(first$1, listPrepend(separator, acc));
    }
  }
}

/**
 * Inserts a given value between each existing element in a given list.
 *
 * This function runs in linear time and copies the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert intersperse([1, 1, 1], 2) == [1, 2, 1, 2, 1]
 * ```
 *
 * ```gleam
 * assert intersperse([], 2) == []
 * ```
 */
export function intersperse(list, elem) {
  if (list instanceof $Empty) {
    return list;
  } else {
    let $ = list.tail;
    if ($ instanceof $Empty) {
      return list;
    } else {
      let first$1 = list.head;
      let rest$1 = $;
      return intersperse_loop(rest$1, elem, toList([first$1]));
    }
  }
}

function unique_loop(loop$list, loop$seen, loop$acc) {
  while (true) {
    let list = loop$list;
    let seen = loop$seen;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = $dict.has_key(seen, first$1);
      if ($) {
        loop$list = rest$1;
        loop$seen = seen;
        loop$acc = acc;
      } else {
        loop$list = rest$1;
        loop$seen = $dict.insert(seen, first$1, undefined);
        loop$acc = listPrepend(first$1, acc);
      }
    }
  }
}

/**
 * Removes any duplicate elements from a given list.
 *
 * This function returns in loglinear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert unique([1, 1, 1, 4, 7, 3, 3, 4]) == [1, 4, 7, 3]
 * ```
 */
export function unique(list) {
  return unique_loop(list, $dict.new$(), toList([]));
}

/**
 * This is exactly the same as merge_ascendings but mirrored: it merges two
 * lists sorted in descending order into a single list sorted in ascending
 * order according to the given comparator function.
 *
 * This reversing of the sort order is not avoidable if we want to implement
 * merge as a tail recursive function. We could reverse the accumulator before
 * returning it but that would end up being less efficient; so the merging
 * algorithm has to play around this.
 * 
 * @ignore
 */
function merge_descendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list2 = loop$list2;
    let compare = loop$compare;
    let acc = loop$acc;
    if (list1 instanceof $Empty) {
      let list = list2;
      return reverse_and_prepend(list, acc);
    } else if (list2 instanceof $Empty) {
      let list = list1;
      return reverse_and_prepend(list, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list2.head;
      let rest2 = list2.tail;
      let $ = compare(first1, first2);
      if ($ instanceof $order.Lt) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare;
        loop$acc = listPrepend(first2, acc);
      } else if ($ instanceof $order.Eq) {
        loop$list1 = rest1;
        loop$list2 = list2;
        loop$compare = compare;
        loop$acc = listPrepend(first1, acc);
      } else {
        loop$list1 = rest1;
        loop$list2 = list2;
        loop$compare = compare;
        loop$acc = listPrepend(first1, acc);
      }
    }
  }
}

/**
 * This is the same as merge_ascending_pairs but flipped for descending lists.
 * 
 * @ignore
 */
function merge_descending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences = loop$sequences;
    let compare = loop$compare;
    let acc = loop$acc;
    if (sequences instanceof $Empty) {
      return reverse(acc);
    } else {
      let $ = sequences.tail;
      if ($ instanceof $Empty) {
        let sequence = sequences.head;
        return reverse(listPrepend(reverse(sequence), acc));
      } else {
        let descending1 = sequences.head;
        let descending2 = $.head;
        let rest$1 = $.tail;
        let ascending = merge_descendings(
          descending1,
          descending2,
          compare,
          toList([]),
        );
        loop$sequences = rest$1;
        loop$compare = compare;
        loop$acc = listPrepend(ascending, acc);
      }
    }
  }
}

/**
 * Merges two lists sorted in ascending order into a single list sorted in
 * descending order according to the given comparator function.
 *
 * This reversing of the sort order is not avoidable if we want to implement
 * merge as a tail recursive function. We could reverse the accumulator before
 * returning it but that would end up being less efficient; so the merging
 * algorithm has to play around this.
 * 
 * @ignore
 */
function merge_ascendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list2 = loop$list2;
    let compare = loop$compare;
    let acc = loop$acc;
    if (list1 instanceof $Empty) {
      let list = list2;
      return reverse_and_prepend(list, acc);
    } else if (list2 instanceof $Empty) {
      let list = list1;
      return reverse_and_prepend(list, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list2.head;
      let rest2 = list2.tail;
      let $ = compare(first1, first2);
      if ($ instanceof $order.Lt) {
        loop$list1 = rest1;
        loop$list2 = list2;
        loop$compare = compare;
        loop$acc = listPrepend(first1, acc);
      } else if ($ instanceof $order.Eq) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare;
        loop$acc = listPrepend(first2, acc);
      } else {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare;
        loop$acc = listPrepend(first2, acc);
      }
    }
  }
}

/**
 * Given a list of ascending lists, it merges adjacent pairs into a single
 * descending list, halving their number.
 * It returns a list of the remaining descending lists.
 * 
 * @ignore
 */
function merge_ascending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences = loop$sequences;
    let compare = loop$compare;
    let acc = loop$acc;
    if (sequences instanceof $Empty) {
      return reverse(acc);
    } else {
      let $ = sequences.tail;
      if ($ instanceof $Empty) {
        let sequence = sequences.head;
        return reverse(listPrepend(reverse(sequence), acc));
      } else {
        let ascending1 = sequences.head;
        let ascending2 = $.head;
        let rest$1 = $.tail;
        let descending = merge_ascendings(
          ascending1,
          ascending2,
          compare,
          toList([]),
        );
        loop$sequences = rest$1;
        loop$compare = compare;
        loop$acc = listPrepend(descending, acc);
      }
    }
  }
}

/**
 * Given some some sorted sequences (assumed to be sorted in `direction`) it
 * merges them all together until we're left with just a list sorted in
 * ascending order.
 * 
 * @ignore
 */
function merge_all(loop$sequences, loop$direction, loop$compare) {
  while (true) {
    let sequences = loop$sequences;
    let direction = loop$direction;
    let compare = loop$compare;
    if (sequences instanceof $Empty) {
      return sequences;
    } else if (direction instanceof Ascending) {
      let $ = sequences.tail;
      if ($ instanceof $Empty) {
        let sequence = sequences.head;
        return sequence;
      } else {
        let sequences$1 = merge_ascending_pairs(sequences, compare, toList([]));
        loop$sequences = sequences$1;
        loop$direction = new Descending();
        loop$compare = compare;
      }
    } else {
      let $ = sequences.tail;
      if ($ instanceof $Empty) {
        let sequence = sequences.head;
        return reverse(sequence);
      } else {
        let sequences$1 = merge_descending_pairs(sequences, compare, toList([]));
        loop$sequences = sequences$1;
        loop$direction = new Ascending();
        loop$compare = compare;
      }
    }
  }
}

/**
 * Given a list it returns slices of it that are locally sorted in ascending
 * order.
 *
 * Imagine you have this list:
 *
 * ```
 *   [1, 2, 3, 2, 1, 0]
 *    ^^^^^^^  ^^^^^^^ This is a slice in descending order
 *    |
 *    | This is a slice that is sorted in ascending order
 * ```
 *
 * So the produced result will contain these two slices, each one sorted in
 * ascending order: `[[1, 2, 3], [0, 1, 2]]`.
 *
 * - `growing` is an accumulator with the current slice being grown
 * - `direction` is the growing direction of the slice being grown, it could
 *   either be ascending or strictly descending
 * - `prev` is the previous element that needs to be added to the growing slice
 *   it is carried around to check whether we have to keep growing the current
 *   slice or not
 * - `acc` is the accumulator containing the slices sorted in ascending order
 * 
 * @ignore
 */
function sequences(
  loop$list,
  loop$compare,
  loop$growing,
  loop$direction,
  loop$prev,
  loop$acc
) {
  while (true) {
    let list = loop$list;
    let compare = loop$compare;
    let growing = loop$growing;
    let direction = loop$direction;
    let prev = loop$prev;
    let acc = loop$acc;
    let growing$1 = listPrepend(prev, growing);
    if (list instanceof $Empty) {
      if (direction instanceof Ascending) {
        return listPrepend(reverse(growing$1), acc);
      } else {
        return listPrepend(growing$1, acc);
      }
    } else {
      let new$1 = list.head;
      let rest$1 = list.tail;
      let $ = compare(prev, new$1);
      if (direction instanceof Ascending) {
        if ($ instanceof $order.Lt) {
          loop$list = rest$1;
          loop$compare = compare;
          loop$growing = growing$1;
          loop$direction = direction;
          loop$prev = new$1;
          loop$acc = acc;
        } else if ($ instanceof $order.Eq) {
          loop$list = rest$1;
          loop$compare = compare;
          loop$growing = growing$1;
          loop$direction = direction;
          loop$prev = new$1;
          loop$acc = acc;
        } else {
          let _block;
          if (direction instanceof Ascending) {
            _block = listPrepend(reverse(growing$1), acc);
          } else {
            _block = listPrepend(growing$1, acc);
          }
          let acc$1 = _block;
          if (rest$1 instanceof $Empty) {
            return listPrepend(toList([new$1]), acc$1);
          } else {
            let next = rest$1.head;
            let rest$2 = rest$1.tail;
            let _block$1;
            let $1 = compare(new$1, next);
            if ($1 instanceof $order.Lt) {
              _block$1 = new Ascending();
            } else if ($1 instanceof $order.Eq) {
              _block$1 = new Ascending();
            } else {
              _block$1 = new Descending();
            }
            let direction$1 = _block$1;
            loop$list = rest$2;
            loop$compare = compare;
            loop$growing = toList([new$1]);
            loop$direction = direction$1;
            loop$prev = next;
            loop$acc = acc$1;
          }
        }
      } else if ($ instanceof $order.Lt) {
        let _block;
        if (direction instanceof Ascending) {
          _block = listPrepend(reverse(growing$1), acc);
        } else {
          _block = listPrepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1 instanceof $Empty) {
          return listPrepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare(new$1, next);
          if ($1 instanceof $order.Lt) {
            _block$1 = new Ascending();
          } else if ($1 instanceof $order.Eq) {
            _block$1 = new Ascending();
          } else {
            _block$1 = new Descending();
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else if ($ instanceof $order.Eq) {
        let _block;
        if (direction instanceof Ascending) {
          _block = listPrepend(reverse(growing$1), acc);
        } else {
          _block = listPrepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1 instanceof $Empty) {
          return listPrepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare(new$1, next);
          if ($1 instanceof $order.Lt) {
            _block$1 = new Ascending();
          } else if ($1 instanceof $order.Eq) {
            _block$1 = new Ascending();
          } else {
            _block$1 = new Descending();
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else {
        loop$list = rest$1;
        loop$compare = compare;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      }
    }
  }
}

/**
 * Sorts from smallest to largest based upon the ordering specified by a given
 * function.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/int
 *
 * assert sort([4, 3, 6, 5, 4, 1, 2], by: int.compare) == [1, 2, 3, 4, 4, 5, 6]
 * ```
 */
export function sort(list, compare) {
  if (list instanceof $Empty) {
    return list;
  } else {
    let $ = list.tail;
    if ($ instanceof $Empty) {
      return list;
    } else {
      let x = list.head;
      let y = $.head;
      let rest$1 = $.tail;
      let _block;
      let $1 = compare(x, y);
      if ($1 instanceof $order.Lt) {
        _block = new Ascending();
      } else if ($1 instanceof $order.Eq) {
        _block = new Ascending();
      } else {
        _block = new Descending();
      }
      let direction = _block;
      let sequences$1 = sequences(
        rest$1,
        compare,
        toList([x]),
        direction,
        y,
        toList([]),
      );
      return merge_all(sequences$1, new Ascending(), compare);
    }
  }
}

function repeat_loop(loop$item, loop$times, loop$acc) {
  while (true) {
    let item = loop$item;
    let times = loop$times;
    let acc = loop$acc;
    let $ = times <= 0;
    if ($) {
      return acc;
    } else {
      loop$item = item;
      loop$times = times - 1;
      loop$acc = listPrepend(item, acc);
    }
  }
}

/**
 * Builds a list of a given value a given number of times.
 *
 * ## Examples
 *
 * ```gleam
 * assert repeat("a", times: 0) == []
 * ```
 *
 * ```gleam
 * assert repeat("a", times: 5) == ["a", "a", "a", "a", "a"]
 * ```
 */
export function repeat(a, times) {
  return repeat_loop(a, times, toList([]));
}

function split_loop(loop$list, loop$n, loop$taken) {
  while (true) {
    let list = loop$list;
    let n = loop$n;
    let taken = loop$taken;
    let $ = n <= 0;
    if ($) {
      return [reverse(taken), list];
    } else {
      if (list instanceof $Empty) {
        return [reverse(taken), toList([])];
      } else {
        let first$1 = list.head;
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$n = n - 1;
        loop$taken = listPrepend(first$1, taken);
      }
    }
  }
}

/**
 * Splits a list in two before the given index.
 *
 * If the list is not long enough to have the given index the before list will
 * be the input list, and the after list will be empty.
 *
 * ## Examples
 *
 * ```gleam
 * assert split([6, 7, 8, 9], 0) == #([], [6, 7, 8, 9])
 * ```
 *
 * ```gleam
 * assert split([6, 7, 8, 9], 2) == #([6, 7], [8, 9])
 * ```
 *
 * ```gleam
 * assert split([6, 7, 8, 9], 4) == #([6, 7, 8, 9], [])
 * ```
 */
export function split(list, index) {
  return split_loop(list, index, toList([]));
}

function split_while_loop(loop$list, loop$f, loop$acc) {
  while (true) {
    let list = loop$list;
    let f = loop$f;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return [reverse(acc), toList([])];
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = f(first$1);
      if ($) {
        loop$list = rest$1;
        loop$f = f;
        loop$acc = listPrepend(first$1, acc);
      } else {
        return [reverse(acc), list];
      }
    }
  }
}

/**
 * Splits a list in two before the first element that a given function returns
 * `False` for.
 *
 * If the function returns `True` for all elements the first list will be the
 * input list, and the second list will be empty.
 *
 * ## Examples
 *
 * ```gleam
 * assert split_while([1, 2, 3, 4, 5], fn(x) { x <= 3 })
 *   == #([1, 2, 3], [4, 5])
 * ```
 *
 * ```gleam
 * assert split_while([1, 2, 3, 4, 5], fn(x) { x <= 5 })
 *   == #([1, 2, 3, 4, 5], [])
 * ```
 */
export function split_while(list, predicate) {
  return split_while_loop(list, predicate, toList([]));
}

/**
 * Given a list of 2-element tuples, finds the first tuple that has a given
 * key as the first element and returns the second element.
 *
 * If no tuple is found with the given key then `Error(Nil)` is returned.
 *
 * This function may be useful for interacting with Erlang code where lists of
 * tuples are common.
 *
 * ## Examples
 *
 * ```gleam
 * assert key_find([#("a", 0), #("b", 1)], "a") == Ok(0)
 * ```
 *
 * ```gleam
 * assert key_find([#("a", 0), #("b", 1)], "b") == Ok(1)
 * ```
 *
 * ```gleam
 * assert key_find([#("a", 0), #("b", 1)], "c") == Error(Nil)
 * ```
 */
export function key_find(keyword_list, desired_key) {
  return find_map(
    keyword_list,
    (keyword) => {
      let key;
      let value;
      key = keyword[0];
      value = keyword[1];
      let $ = isEqual(key, desired_key);
      if ($) {
        return new Ok(value);
      } else {
        return new Error(undefined);
      }
    },
  );
}

/**
 * Given a list of 2-element tuples, finds all tuples that have a given
 * key as the first element and returns the second element.
 *
 * This function may be useful for interacting with Erlang code where lists of
 * tuples are common.
 *
 * ## Examples
 *
 * ```gleam
 * assert key_filter([#("a", 0), #("b", 1), #("a", 2)], "a") == [0, 2]
 * ```
 *
 * ```gleam
 * assert key_filter([#("a", 0), #("b", 1)], "c") == []
 * ```
 */
export function key_filter(keyword_list, desired_key) {
  return filter_map(
    keyword_list,
    (keyword) => {
      let key;
      let value;
      key = keyword[0];
      value = keyword[1];
      let $ = isEqual(key, desired_key);
      if ($) {
        return new Ok(value);
      } else {
        return new Error(undefined);
      }
    },
  );
}

function key_pop_loop(loop$list, loop$key, loop$checked) {
  while (true) {
    let list = loop$list;
    let key = loop$key;
    let checked = loop$checked;
    if (list instanceof $Empty) {
      return new Error(undefined);
    } else {
      let k = list.head[0];
      if (isEqual(k, key)) {
        let rest$1 = list.tail;
        let v = list.head[1];
        return new Ok([v, reverse_and_prepend(checked, rest$1)]);
      } else {
        let first$1 = list.head;
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$key = key;
        loop$checked = listPrepend(first$1, checked);
      }
    }
  }
}

/**
 * Given a list of 2-element tuples, finds the first tuple that has a given
 * key as the first element. This function will return the second element
 * of the found tuple and list with tuple removed.
 *
 * If no tuple is found with the given key then `Error(Nil)` is returned.
 *
 * ## Examples
 *
 * ```gleam
 * assert key_pop([#("a", 0), #("b", 1)], "a") == Ok(#(0, [#("b", 1)]))
 * ```
 *
 * ```gleam
 * assert key_pop([#("a", 0), #("b", 1)], "b") == Ok(#(1, [#("a", 0)]))
 * ```
 *
 * ```gleam
 * assert key_pop([#("a", 0), #("b", 1)], "c") == Error(Nil)
 * ```
 */
export function key_pop(list, key) {
  return key_pop_loop(list, key, toList([]));
}

function key_set_loop(loop$list, loop$key, loop$value, loop$inspected) {
  while (true) {
    let list = loop$list;
    let key = loop$key;
    let value = loop$value;
    let inspected = loop$inspected;
    if (list instanceof $Empty) {
      return reverse(listPrepend([key, value], inspected));
    } else {
      let k = list.head[0];
      if (isEqual(k, key)) {
        let rest$1 = list.tail;
        return reverse_and_prepend(inspected, listPrepend([k, value], rest$1));
      } else {
        let first$1 = list.head;
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$key = key;
        loop$value = value;
        loop$inspected = listPrepend(first$1, inspected);
      }
    }
  }
}

/**
 * Given a list of 2-element tuples, inserts a key and value into the list.
 *
 * If there was already a tuple with the key then it is replaced, otherwise it
 * is added to the end of the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert key_set([#(5, 0), #(4, 1)], 4, 100) == [#(5, 0), #(4, 100)]
 * ```
 *
 * ```gleam
 * assert key_set([#(5, 0), #(4, 1)], 1, 100) == [#(5, 0), #(4, 1), #(1, 100)]
 * ```
 */
export function key_set(list, key, value) {
  return key_set_loop(list, key, value, toList([]));
}

/**
 * Calls a function for each element in a list, discarding the return value.
 *
 * Useful for calling a side effect for every item of a list.
 *
 * ```gleam
 * import gleam/io
 *
 * assert each(["1", "2", "3"], io.println) == Nil
 * // 1
 * // 2
 * // 3
 * ```
 */
export function each(loop$list, loop$f) {
  while (true) {
    let list = loop$list;
    let f = loop$f;
    if (list instanceof $Empty) {
      return undefined;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      f(first$1);
      loop$list = rest$1;
      loop$f = f;
    }
  }
}

/**
 * Calls a `Result` returning function for each element in a list, discarding
 * the return value. If the function returns `Error` then the iteration is
 * stopped and the error is returned.
 *
 * Useful for calling a side effect for every item of a list.
 *
 * ## Examples
 *
 * ```gleam
 * assert
 *   try_each(
 *     over: [1, 2, 3],
 *     with: function_that_might_fail,
 *   )
 *   == Ok(Nil)
 * ```
 */
export function try_each(loop$list, loop$fun) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    if (list instanceof $Empty) {
      return new Ok(undefined);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = fun(first$1);
      if ($ instanceof Ok) {
        loop$list = rest$1;
        loop$fun = fun;
      } else {
        return $;
      }
    }
  }
}

function partition_loop(loop$list, loop$categorise, loop$trues, loop$falses) {
  while (true) {
    let list = loop$list;
    let categorise = loop$categorise;
    let trues = loop$trues;
    let falses = loop$falses;
    if (list instanceof $Empty) {
      return [reverse(trues), reverse(falses)];
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = categorise(first$1);
      if ($) {
        loop$list = rest$1;
        loop$categorise = categorise;
        loop$trues = listPrepend(first$1, trues);
        loop$falses = falses;
      } else {
        loop$list = rest$1;
        loop$categorise = categorise;
        loop$trues = trues;
        loop$falses = listPrepend(first$1, falses);
      }
    }
  }
}

/**
 * Partitions a list into a tuple/pair of lists
 * by a given categorisation function.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/int
 *
 * assert [1, 2, 3, 4, 5] |> partition(int.is_odd) == #([1, 3, 5], [2, 4])
 * ```
 */
export function partition(list, categorise) {
  return partition_loop(list, categorise, toList([]), toList([]));
}

function permutation_prepend(
  loop$el,
  loop$permutations,
  loop$list_1,
  loop$list_2,
  loop$acc
) {
  while (true) {
    let el = loop$el;
    let permutations = loop$permutations;
    let list_1 = loop$list_1;
    let list_2 = loop$list_2;
    let acc = loop$acc;
    if (permutations instanceof $Empty) {
      return permutation_zip(list_1, list_2, acc);
    } else {
      let head = permutations.head;
      let tail = permutations.tail;
      loop$el = el;
      loop$permutations = tail;
      loop$list_1 = list_1;
      loop$list_2 = list_2;
      loop$acc = listPrepend(listPrepend(el, head), acc);
    }
  }
}

function permutation_zip(list, rest, acc) {
  if (list instanceof $Empty) {
    return reverse(acc);
  } else {
    let head = list.head;
    let tail = list.tail;
    return permutation_prepend(
      head,
      permutations(reverse_and_prepend(rest, tail)),
      tail,
      listPrepend(head, rest),
      acc,
    );
  }
}

/**
 * Returns all the permutations of a list.
 *
 * ## Examples
 *
 * ```gleam
 * assert permutations([1, 2]) == [[1, 2], [2, 1]]
 * ```
 */
export function permutations(list) {
  if (list instanceof $Empty) {
    return toList([toList([])]);
  } else {
    let l = list;
    return permutation_zip(l, toList([]), toList([]));
  }
}

function window_loop(loop$acc, loop$list, loop$n) {
  while (true) {
    let acc = loop$acc;
    let list = loop$list;
    let n = loop$n;
    let window$1 = take(list, n);
    let $ = length(window$1) === n;
    if ($) {
      loop$acc = listPrepend(window$1, acc);
      loop$list = drop(list, 1);
      loop$n = n;
    } else {
      return reverse(acc);
    }
  }
}

/**
 * Returns a list of sliding windows.
 *
 * ## Examples
 *
 * ```gleam
 * assert window([1,2,3,4,5], 3) == [[1, 2, 3], [2, 3, 4], [3, 4, 5]]
 * ```
 *
 * ```gleam
 * assert window([1, 2], 4) == []
 * ```
 */
export function window(list, n) {
  let $ = n <= 0;
  if ($) {
    return toList([]);
  } else {
    return window_loop(toList([]), list, n);
  }
}

/**
 * Returns a list of tuples containing two contiguous elements.
 *
 * ## Examples
 *
 * ```gleam
 * assert window_by_2([1,2,3,4]) == [#(1, 2), #(2, 3), #(3, 4)]
 * ```
 *
 * ```gleam
 * assert window_by_2([1]) == []
 * ```
 */
export function window_by_2(list) {
  return zip(list, drop(list, 1));
}

/**
 * Drops the first elements in a given list for which the predicate function returns `True`.
 *
 * ## Examples
 *
 * ```gleam
 * assert drop_while([1, 2, 3, 4], fn (x) { x < 3 }) == [3, 4]
 * ```
 */
export function drop_while(loop$list, loop$predicate) {
  while (true) {
    let list = loop$list;
    let predicate = loop$predicate;
    if (list instanceof $Empty) {
      return list;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = predicate(first$1);
      if ($) {
        loop$list = rest$1;
        loop$predicate = predicate;
      } else {
        return listPrepend(first$1, rest$1);
      }
    }
  }
}

function take_while_loop(loop$list, loop$predicate, loop$acc) {
  while (true) {
    let list = loop$list;
    let predicate = loop$predicate;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = predicate(first$1);
      if ($) {
        loop$list = rest$1;
        loop$predicate = predicate;
        loop$acc = listPrepend(first$1, acc);
      } else {
        return reverse(acc);
      }
    }
  }
}

/**
 * Takes the first elements in a given list for which the predicate function returns `True`.
 *
 * ## Examples
 *
 * ```gleam
 * assert take_while([1, 2, 3, 2, 4], fn (x) { x < 3 }) == [1, 2]
 * ```
 */
export function take_while(list, predicate) {
  return take_while_loop(list, predicate, toList([]));
}

function chunk_loop(
  loop$list,
  loop$f,
  loop$previous_key,
  loop$current_chunk,
  loop$acc
) {
  while (true) {
    let list = loop$list;
    let f = loop$f;
    let previous_key = loop$previous_key;
    let current_chunk = loop$current_chunk;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return reverse(listPrepend(reverse(current_chunk), acc));
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let key = f(first$1);
      let $ = isEqual(key, previous_key);
      if ($) {
        loop$list = rest$1;
        loop$f = f;
        loop$previous_key = key;
        loop$current_chunk = listPrepend(first$1, current_chunk);
        loop$acc = acc;
      } else {
        let new_acc = listPrepend(reverse(current_chunk), acc);
        loop$list = rest$1;
        loop$f = f;
        loop$previous_key = key;
        loop$current_chunk = toList([first$1]);
        loop$acc = new_acc;
      }
    }
  }
}

/**
 * Returns a list of chunks in which
 * the return value of calling `f` on each element is the same.
 *
 * ## Examples
 *
 * ```gleam
 * assert [1, 2, 2, 3, 4, 4, 6, 7, 7] |> chunk(by: fn(n) { n % 2 })
 *   == [[1], [2, 2], [3], [4, 4, 6], [7, 7]]
 * ```
 */
export function chunk(list, f) {
  if (list instanceof $Empty) {
    return list;
  } else {
    let first$1 = list.head;
    let rest$1 = list.tail;
    return chunk_loop(rest$1, f, f(first$1), toList([first$1]), toList([]));
  }
}

function sized_chunk_loop(
  loop$list,
  loop$count,
  loop$left,
  loop$current_chunk,
  loop$acc
) {
  while (true) {
    let list = loop$list;
    let count = loop$count;
    let left = loop$left;
    let current_chunk = loop$current_chunk;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      if (current_chunk instanceof $Empty) {
        return reverse(acc);
      } else {
        let remaining = current_chunk;
        return reverse(listPrepend(reverse(remaining), acc));
      }
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let chunk$1 = listPrepend(first$1, current_chunk);
      let $ = left > 1;
      if ($) {
        loop$list = rest$1;
        loop$count = count;
        loop$left = left - 1;
        loop$current_chunk = chunk$1;
        loop$acc = acc;
      } else {
        loop$list = rest$1;
        loop$count = count;
        loop$left = count;
        loop$current_chunk = toList([]);
        loop$acc = listPrepend(reverse(chunk$1), acc);
      }
    }
  }
}

/**
 * Returns a list of chunks containing `count` elements each.
 *
 * If the last chunk does not have `count` elements, it is instead
 * a partial chunk, with less than `count` elements.
 *
 * For any `count` less than 1 this function behaves as if it was set to 1.
 *
 * ## Examples
 *
 * ```gleam
 * assert [1, 2, 3, 4, 5, 6] |> sized_chunk(into: 2)
 *   == [[1, 2], [3, 4], [5, 6]]
 * ```
 *
 * ```gleam
 * assert [1, 2, 3, 4, 5, 6, 7, 8] |> sized_chunk(into: 3)
 *   == [[1, 2, 3], [4, 5, 6], [7, 8]]
 * ```
 */
export function sized_chunk(list, count) {
  return sized_chunk_loop(list, count, count, toList([]), toList([]));
}

/**
 * This function acts similar to fold, but does not take an initial state.
 * Instead, it starts from the first element in the list
 * and combines it with each subsequent element in turn using the given
 * function. The function is called as `fun(accumulator, current_element)`.
 *
 * Returns `Ok` to indicate a successful run, and `Error` if called on an
 * empty list.
 *
 * ## Examples
 *
 * ```gleam
 * assert [] |> reduce(fn(acc, x) { acc + x }) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert [1, 2, 3, 4, 5] |> reduce(fn(acc, x) { acc + x }) == Ok(15)
 * ```
 */
export function reduce(list, fun) {
  if (list instanceof $Empty) {
    return new Error(undefined);
  } else {
    let first$1 = list.head;
    let rest$1 = list.tail;
    return new Ok(fold(rest$1, first$1, fun));
  }
}

function scan_loop(loop$list, loop$accumulator, loop$accumulated, loop$fun) {
  while (true) {
    let list = loop$list;
    let accumulator = loop$accumulator;
    let accumulated = loop$accumulated;
    let fun = loop$fun;
    if (list instanceof $Empty) {
      return reverse(accumulated);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let next = fun(accumulator, first$1);
      loop$list = rest$1;
      loop$accumulator = next;
      loop$accumulated = listPrepend(next, accumulated);
      loop$fun = fun;
    }
  }
}

/**
 * Similar to `fold`, but yields the state of the accumulator at each stage.
 *
 * ## Examples
 *
 * ```gleam
 * assert scan(over: [1, 2, 3], from: 100, with: fn(acc, i) { acc + i })
 *   == [101, 103, 106]
 * ```
 */
export function scan(list, initial, fun) {
  return scan_loop(list, initial, toList([]), fun);
}

/**
 * Returns the last element in the given list.
 *
 * Returns `Error(Nil)` if the list is empty.
 *
 * This function runs in linear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert last([]) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert last([1, 2, 3, 4, 5]) == Ok(5)
 * ```
 */
export function last(loop$list) {
  while (true) {
    let list = loop$list;
    if (list instanceof $Empty) {
      return new Error(undefined);
    } else {
      let $ = list.tail;
      if ($ instanceof $Empty) {
        let last$1 = list.head;
        return new Ok(last$1);
      } else {
        let rest$1 = $;
        loop$list = rest$1;
      }
    }
  }
}

/**
 * Return unique combinations of elements in the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert combinations([1, 2, 3], 2) == [[1, 2], [1, 3], [2, 3]]
 * ```
 *
 * ```gleam
 * assert combinations([1, 2, 3, 4], 3)
 *   == [[1, 2, 3], [1, 2, 4], [1, 3, 4], [2, 3, 4]]
 * ```
 */
export function combinations(items, n) {
  if (n === 0) {
    return toList([toList([])]);
  } else if (items instanceof $Empty) {
    return items;
  } else {
    let first$1 = items.head;
    let rest$1 = items.tail;
    let _pipe = rest$1;
    let _pipe$1 = combinations(_pipe, n - 1);
    let _pipe$2 = map(
      _pipe$1,
      (combination) => { return listPrepend(first$1, combination); },
    );
    let _pipe$3 = reverse(_pipe$2);
    return fold(
      _pipe$3,
      combinations(rest$1, n),
      (acc, c) => { return listPrepend(c, acc); },
    );
  }
}

function combination_pairs_loop(loop$items, loop$acc) {
  while (true) {
    let items = loop$items;
    let acc = loop$acc;
    if (items instanceof $Empty) {
      return reverse(acc);
    } else {
      let first$1 = items.head;
      let rest$1 = items.tail;
      let first_combinations = map(
        rest$1,
        (other) => { return [first$1, other]; },
      );
      let acc$1 = reverse_and_prepend(first_combinations, acc);
      loop$items = rest$1;
      loop$acc = acc$1;
    }
  }
}

/**
 * Return unique pair combinations of elements in the list.
 *
 * ## Examples
 *
 * ```gleam
 * assert combination_pairs([1, 2, 3]) == [#(1, 2), #(1, 3), #(2, 3)]
 * ```
 */
export function combination_pairs(items) {
  return combination_pairs_loop(items, toList([]));
}

function take_firsts(loop$rows, loop$column, loop$remaining_rows) {
  while (true) {
    let rows = loop$rows;
    let column = loop$column;
    let remaining_rows = loop$remaining_rows;
    if (rows instanceof $Empty) {
      return [reverse(column), reverse(remaining_rows)];
    } else {
      let $ = rows.head;
      if ($ instanceof $Empty) {
        let rest$1 = rows.tail;
        loop$rows = rest$1;
        loop$column = column;
        loop$remaining_rows = remaining_rows;
      } else {
        let rest_rows = rows.tail;
        let first$1 = $.head;
        let remaining_row = $.tail;
        let remaining_rows$1 = listPrepend(remaining_row, remaining_rows);
        loop$rows = rest_rows;
        loop$column = listPrepend(first$1, column);
        loop$remaining_rows = remaining_rows$1;
      }
    }
  }
}

function transpose_loop(loop$rows, loop$columns) {
  while (true) {
    let rows = loop$rows;
    let columns = loop$columns;
    if (rows instanceof $Empty) {
      return reverse(columns);
    } else {
      let $ = take_firsts(rows, toList([]), toList([]));
      let column;
      let rest$1;
      column = $[0];
      rest$1 = $[1];
      if (column instanceof $Empty) {
        loop$rows = rest$1;
        loop$columns = columns;
      } else {
        loop$rows = rest$1;
        loop$columns = listPrepend(column, columns);
      }
    }
  }
}

/**
 * Transpose rows and columns of the list of lists.
 *
 * Notice: This function is not tail recursive,
 * and thus may exceed stack size if called,
 * with large lists (on the JavaScript target).
 *
 * ## Examples
 *
 * ```gleam
 * assert transpose([[1, 2, 3], [101, 102, 103]])
 *   == [[1, 101], [2, 102], [3, 103]]
 * ```
 */
export function transpose(list_of_lists) {
  return transpose_loop(list_of_lists, toList([]));
}

/**
 * Make a list alternating the elements from the given lists
 *
 * ## Examples
 *
 * ```gleam
 * assert interleave([[1, 2], [101, 102], [201, 202]])
 *   == [1, 101, 201, 2, 102, 202]
 * ```
 */
export function interleave(list) {
  let _pipe = list;
  let _pipe$1 = transpose(_pipe);
  return flatten(_pipe$1);
}

function shuffle_pair_unwrap_loop(loop$list, loop$acc) {
  while (true) {
    let list = loop$list;
    let acc = loop$acc;
    if (list instanceof $Empty) {
      return acc;
    } else {
      let elem_pair = list.head;
      let enumerable = list.tail;
      loop$list = enumerable;
      loop$acc = listPrepend(elem_pair[1], acc);
    }
  }
}

function do_shuffle_by_pair_indexes(list_of_pairs) {
  return sort(
    list_of_pairs,
    (a_pair, b_pair) => { return $float.compare(a_pair[0], b_pair[0]); },
  );
}

/**
 * Takes a list, randomly sorts all items and returns the shuffled list.
 *
 * This function uses `float.random` to decide the order of the elements.
 *
 * ## Example
 *
 * ```gleam
 * [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] |> shuffle
 * // -> [1, 6, 9, 10, 3, 8, 4, 2, 7, 5]
 * ```
 */
export function shuffle(list) {
  let _pipe = list;
  let _pipe$1 = fold(
    _pipe,
    toList([]),
    (acc, a) => { return listPrepend([$float.random(), a], acc); },
  );
  let _pipe$2 = do_shuffle_by_pair_indexes(_pipe$1);
  return shuffle_pair_unwrap_loop(_pipe$2, toList([]));
}

function max_loop(loop$list, loop$compare, loop$max) {
  while (true) {
    let list = loop$list;
    let compare = loop$compare;
    let max = loop$max;
    if (list instanceof $Empty) {
      return max;
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let $ = compare(first$1, max);
      if ($ instanceof $order.Lt) {
        loop$list = rest$1;
        loop$compare = compare;
        loop$max = max;
      } else if ($ instanceof $order.Eq) {
        loop$list = rest$1;
        loop$compare = compare;
        loop$max = max;
      } else {
        loop$list = rest$1;
        loop$compare = compare;
        loop$max = first$1;
      }
    }
  }
}

/**
 * Takes a list and a comparator, and returns the maximum element in the list
 *
 * ## Examples
 *
 * ```gleam
 * assert [1, 2, 3, 4, 5] |> list.max(int.compare) == Ok(5)
 * ```
 *
 * ```gleam
 * assert ["a", "c", "b"] |> list.max(string.compare) == Ok("c")
 * ```
 */
export function max(list, compare) {
  if (list instanceof $Empty) {
    return new Error(undefined);
  } else {
    let first$1 = list.head;
    let rest$1 = list.tail;
    return new Ok(max_loop(rest$1, compare, first$1));
  }
}

function log_random() {
  let $ = $float.logarithm($float.random() + min_positive);
  let random;
  if ($ instanceof Ok) {
    random = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gleam/list",
      2244,
      "log_random",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 55129,
        end: 55200,
        pattern_start: 55140,
        pattern_end: 55150
      }
    )
  }
  return random;
}

function sample_loop(loop$list, loop$reservoir, loop$n, loop$w) {
  while (true) {
    let list = loop$list;
    let reservoir = loop$reservoir;
    let n = loop$n;
    let w = loop$w;
    let _block;
    {
      let $ = $float.logarithm(1.0 - w);
      let log;
      if ($ instanceof Ok) {
        log = $[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gleam/list",
          2227,
          "sample_loop",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 54690,
            end: 54736,
            pattern_start: 54701,
            pattern_end: 54708
          }
        )
      }
      _block = $float.round($float.floor(divideFloat(log_random(), log)));
    }
    let skip = _block;
    let $ = drop(list, skip);
    if ($ instanceof $Empty) {
      return reservoir;
    } else {
      let first$1 = $.head;
      let rest$1 = $.tail;
      let reservoir$1 = $dict.insert(reservoir, $int.random(n), first$1);
      let w$1 = w * $float.exponential(
        divideFloat(log_random(), $int.to_float(n)),
      );
      loop$list = rest$1;
      loop$reservoir = reservoir$1;
      loop$n = n;
      loop$w = w$1;
    }
  }
}

function build_reservoir_loop(loop$list, loop$size, loop$reservoir) {
  while (true) {
    let list = loop$list;
    let size = loop$size;
    let reservoir = loop$reservoir;
    let reservoir_size = $dict.size(reservoir);
    let $ = reservoir_size >= size;
    if ($) {
      return [reservoir, list];
    } else {
      if (list instanceof $Empty) {
        return [reservoir, toList([])];
      } else {
        let first$1 = list.head;
        let rest$1 = list.tail;
        let reservoir$1 = $dict.insert(reservoir, reservoir_size, first$1);
        loop$list = rest$1;
        loop$size = size;
        loop$reservoir = reservoir$1;
      }
    }
  }
}

/**
 * Builds the initial reservoir used by Algorithm L.
 * This is a dictionary with keys ranging from `0` up to `n - 1` where each
 * value is the corresponding element at that position in `list`.
 *
 * This also returns the remaining elements of `list` that didn't end up in
 * the reservoir.
 * 
 * @ignore
 */
function build_reservoir(list, n) {
  return build_reservoir_loop(list, n, $dict.new$());
}

/**
 * Returns a random sample of up to n elements from a list using reservoir
 * sampling via [Algorithm L](https://en.wikipedia.org/wiki/Reservoir_sampling#Optimal:_Algorithm_L).
 * Returns an empty list if the sample size is less than or equal to 0.
 *
 * Order is not random, only selection is.
 *
 * ## Examples
 *
 * ```gleam
 * sample([1, 2, 3, 4, 5], 3)
 * // -> [2, 4, 5]  // A random sample of 3 items
 * ```
 */
export function sample(list, n) {
  let $ = build_reservoir(list, n);
  let reservoir;
  let rest$1;
  reservoir = $[0];
  rest$1 = $[1];
  let $1 = $dict.is_empty(reservoir);
  if ($1) {
    return toList([]);
  } else {
    let w = $float.exponential(divideFloat(log_random(), $int.to_float(n)));
    return $dict.values(sample_loop(rest$1, reservoir, n, w));
  }
}
