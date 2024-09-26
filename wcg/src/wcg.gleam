import argv
import file_streams/file_stream
import file_streams/file_stream_error
import gleam/int
import gleam/io
import gleam/iterator
import gleam/list
import gleam/result
import gleam/string

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
        let res = stream |> count
        case stream |> file_stream.close {
          Error(err) -> Error(err |> as_unknown_error)
          Ok(_) -> Ok(res)
        }
      }
    }
    |> result.flatten
    |> result.map_error(fn(err) { err |> error_message |> io.println_error })
    |> result.map(fn(res) {
      let #(l, w, c, b) = res
      let counts = #(l, w, c, b, input)
      counts |> format_output(args) |> io.println
      counts
    })
  })
}

fn count(
  stream: file_stream.FileStream,
) -> Result(#(Int, Int, Int, Int), WcError) {
  {
    use l <- result.map(stream |> count_lines)
    use _ <- result.map(stream |> stream_position_zero)
    use w <- result.map(stream |> count_words)
    use _ <- result.map(stream |> stream_position_zero)
    use c <- result.map(stream |> count_chars)
    use _ <- result.map(stream |> stream_position_zero)
    #(l, w, c, 0)
  }
  |> result.flatten
  |> result.flatten
  |> result.flatten
  |> result.flatten
  |> result.flatten
  |> result.map_error(fn(err) { err |> as_unknown_error })
}

fn count_lines(
  stream: file_stream.FileStream,
) -> Result(Int, file_stream_error.FileStreamError) {
  iterator.repeatedly(fn() {
    case stream |> file_stream.read_line {
      Error(file_stream_error.Eof) -> Error(file_stream_error.Eof)
      Error(err) -> Ok(Error(err))
      Ok(_) -> Ok(Ok(1))
    }
  })
  |> iterator.take_while(result.is_ok)
  |> iterator.map(result.flatten)
  |> iterator.try_fold(0, fn(acc, r) { r |> result.map(fn(n) { acc + n }) })
}

fn count_words(
  stream: file_stream.FileStream,
) -> Result(Int, file_stream_error.FileStreamError) {
  iterator.repeatedly(fn() {
    case stream |> file_stream.read_line {
      Error(file_stream_error.Eof) -> Error(file_stream_error.Eof)
      Error(err) -> Ok(Error(err))
      Ok(line) -> Ok(Ok(line))
    }
  })
  |> iterator.take_while(result.is_ok)
  |> iterator.map(result.flatten)
  |> iterator.try_fold(0, fn(acc, r) {
    result.map(r, fn(line) {
      let n =
        line
        |> string.trim
        |> string.split(" ")
        |> list.count(fn(word) { word != "" })
      acc + n
    })
  })
}

fn count_chars(
  stream: file_stream.FileStream,
) -> Result(Int, file_stream_error.FileStreamError) {
  iterator.repeatedly(fn() {
    case stream |> file_stream.read_line {
      Error(file_stream_error.Eof) -> Error(file_stream_error.Eof)
      Error(err) -> Ok(Error(err))
      Ok(line) -> Ok(Ok(line))
    }
  })
  |> iterator.take_while(result.is_ok)
  |> iterator.map(result.flatten)
  |> iterator.try_fold(0, fn(acc, r) {
    result.map(r, fn(line) { acc + string.length(line) })
  })
}

fn stream_position_zero(
  stream: file_stream.FileStream,
) -> Result(Int, file_stream_error.FileStreamError) {
  stream |> file_stream.position(file_stream.BeginningOfFile(0))
}

fn format_output(counts: #(Int, Int, Int, Int, String), args: Args) -> String {
  let #(l, w, c, b, input) = counts
  case args.lines {
    True -> int.to_string(l) <> " "
    _ -> ""
  }
  <> case args.words {
    True -> int.to_string(w) <> " "
    _ -> ""
  }
  <> case args.chars {
    True -> int.to_string(c) <> " "
    _ -> ""
  }
  <> case args.bytes {
    True -> int.to_string(b) <> " "
    _ -> ""
  }
  <> input
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
