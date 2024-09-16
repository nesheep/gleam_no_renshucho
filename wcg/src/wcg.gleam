import argv
import gleam/io
import gleam/list
import gleam/result

type Args {
  Args(
    /// input file names
    inputs: List(String),
    /// -l
    lines: Bool,
    /// -w
    words: Bool,
    /// -c
    bytes: Bool,
    /// -m
    chars: Bool,
  )
}

type WcError {
  InvalidOptionError(arg: String)
  IsDirError(arg: String)
  NoEntryError(arg: String)
  UnknownError
}

fn error_message(err: WcError) -> String {
  "wcg: "
  <> case err {
    InvalidOptionError(arg) -> "invalid option -- '" <> arg <> "'"
    IsDirError(arg) -> arg <> "': Is a directory"
    NoEntryError(arg) -> arg <> ": No such file or directory"
    UnknownError -> "unknown error"
  }
}

fn parse_args(args: List(String)) -> Result(Args, WcError) {
  args
  |> list.try_fold(Args([], False, False, False, False), fn(acc, arg) {
    case arg {
      "-" <> opt ->
        case opt {
          "l" -> Ok(Args(..acc, lines: True))
          "w" -> Ok(Args(..acc, words: True))
          "c" -> Ok(Args(..acc, bytes: True))
          "m" -> Ok(Args(..acc, chars: True))
          _ -> Error(InvalidOptionError(opt))
        }
      input -> Ok(Args(..acc, inputs: [input, ..acc.inputs]))
    }
  })
  |> result.map(fn(r) { Args(..r, inputs: list.reverse(r.inputs)) })
  |> result.map(fn(r) {
    case r {
      Args(_, False, False, False, False) ->
        Args(..r, lines: True, words: True, bytes: True)
      _ -> r
    }
  })
}

fn run(args: Args) -> Nil {
  io.debug(args)
  Nil
}

pub fn main() {
  case argv.load().arguments |> parse_args {
    Error(err) -> err |> error_message |> io.println
    Ok(args) -> args |> run
  }
}
