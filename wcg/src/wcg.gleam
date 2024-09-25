import argv
import file_streams/file_stream
import file_streams/file_stream_error
import gleam/int
import gleam/io
import gleam/iterator
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
  let Args(inputs, ..) = args

  list.each(inputs, fn(input) {
    case file_stream.open_read(input) {
      Error(err) -> Error(err |> map_file_error(input))
      Ok(stream) -> {
        let res =
          {
            // count lines
            let rl =
              iterator.repeatedly(fn() {
                case stream |> file_stream.read_line {
                  Error(file_stream_error.Eof) -> Error(file_stream_error.Eof)
                  Error(err) -> Ok(Error(err))
                  Ok(_) -> Ok(Ok(1))
                }
              })
              |> iterator.take_while(result.is_ok)
              |> iterator.map(result.flatten)
              |> iterator.try_fold(0, fn(acc, r) {
                r |> result.map(fn(n) { acc + n })
              })
            use l <- result.map(rl)

            #(l)
          }
          |> result.map_error(fn(err) { err |> as_unknown_error })

        case stream |> file_stream.close {
          Error(err) -> Error(err |> as_unknown_error)
          Ok(_) -> Ok(res)
        }
      }
    }
    |> result.flatten
    |> result.map_error(fn(err) { err |> error_message |> io.println_error })
    |> result.map(fn(res) {
      let #(l) = res
      { int.to_string(l) <> " " <> input } |> io.println
      #(l, input)
    })
  })
}

fn map_file_error(
  err: file_stream_error.FileStreamError,
  arg: String,
) -> WcError {
  case err {
    file_stream_error.Eisdir -> IsDirError(arg)
    file_stream_error.Enoent -> NoEntryError(arg)
    _ -> UnknownError
  }
}

fn as_unknown_error(err: a) -> WcError {
  err |> io.debug
  UnknownError
}

pub fn main() {
  case argv.load().arguments |> parse_args {
    Error(err) -> err |> error_message |> io.println_error
    Ok(args) -> args |> run
  }
}
