import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}

type Args {
  Args(
    /// input file names
    inputs: List(String),
    /// -n NUM
    lines: Option(Int),
    /// -c NUM
    bytes: Option(Int),
  )
}

type HeadError {
  InvalidLinesError(arg: String)
  InvalidBytesError(arg: String)
  ArgRequiredError(arg: String)
}

fn parse_args(args: List(String)) -> Result(Args, HeadError) {
  args_loop(args, Args([], None, None))
}

fn args_loop(args: List(String), acc: Args) -> Result(Args, HeadError) {
  let Args(inputs:, lines:, bytes:) = acc
  case args {
    [] -> Ok(Args(list.reverse(inputs), lines, bytes))
    ["-n", ..rest] -> {
      case rest {
        [] -> Error(ArgRequiredError("n"))
        [first, ..rest] ->
          case parse_uint(first) {
            Error(_) -> Error(InvalidLinesError(first))
            Ok(i) -> args_loop(rest, Args(inputs, Some(i), bytes))
          }
      }
    }
    ["-c", ..rest] -> {
      case rest {
        [] -> Error(ArgRequiredError("c"))
        [first, ..rest] ->
          case parse_uint(first) {
            Error(_) -> Error(InvalidBytesError(first))
            Ok(i) -> args_loop(rest, Args(inputs, lines, Some(i)))
          }
      }
    }
    [first, ..rest] -> args_loop(rest, Args([first, ..inputs], lines, bytes))
  }
}

fn parse_uint(a: String) -> Result(Int, Nil) {
  case int.parse(a) {
    Error(_) -> Error(Nil)
    Ok(i) if i < 0 -> Error(Nil)
    Ok(i) -> Ok(i)
  }
}

pub fn main() {
  let _ = argv.load().arguments |> parse_args |> io.debug
  Nil
}
