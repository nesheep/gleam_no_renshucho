import argv
import file_streams/file_stream
import file_streams/file_stream_error
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/iterator
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

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
  IsDirError(arg: String)
  NoEntryError(arg: String)
  UnknownError
}

fn error_message(err: HeadError) -> String {
  "headg: "
  <> case err {
    InvalidLinesError(arg) -> "invalid number of lines: '" <> arg <> "'"
    InvalidBytesError(arg) -> "invalid number of bytes: '" <> arg <> "'"
    ArgRequiredError(arg) -> "option requires an argument -- '" <> arg <> "'"
    IsDirError(arg) -> "error reading '" <> arg <> "': Is a directory"
    NoEntryError(arg) ->
      "cannot open '" <> arg <> "' for reading: No such file or directory"
    UnknownError -> "unknown error"
  }
}

fn parse_args(args: List(String)) -> Result(Args, HeadError) {
  args_loop(args, Args([], None, None))
}

fn args_loop(args: List(String), acc: Args) -> Result(Args, HeadError) {
  let Args(inputs, lines, bytes) = acc
  case args {
    [] -> Ok(Args(list.reverse(inputs), lines, bytes))
    ["-n", ..rest] ->
      case rest {
        [] -> Error(ArgRequiredError("n"))
        [first, ..rest] ->
          case parse_uint(first) {
            Error(_) -> Error(InvalidLinesError(first))
            Ok(i) -> args_loop(rest, Args(inputs, Some(i), bytes))
          }
      }
    ["-c", ..rest] ->
      case rest {
        [] -> Error(ArgRequiredError("c"))
        [first, ..rest] ->
          case parse_uint(first) {
            Error(_) -> Error(InvalidBytesError(first))
            Ok(i) -> args_loop(rest, Args(inputs, lines, Some(i)))
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

fn run(args: Args) -> Nil {
  let Args(inputs, lines, bytes) = args
  let len = list.length(inputs)

  let iter = inputs |> iterator.from_list |> iterator.index
  use #(input, i) <- iterator.each(iter)
  case file_stream.open_read(input) {
    Error(err) -> err |> map_file_error(input) |> error_message |> io.println
    Ok(stream) -> {
      // 複数ファイル指定の場合はファイル名表示
      case len > 1 {
        True -> io.println("==> " <> input <> " <==")
        _ -> Nil
      }
      // メイン処理
      print_steam(stream, lines, bytes)
      // 最後のファイル以外は改行を挿入
      case i != len - 1 {
        True -> io.println("")
        _ -> Nil
      }
      stream
      |> file_stream.close
      |> result.map_error(io.debug)
      |> result.unwrap(Nil)
    }
  }
}

fn map_file_error(
  err: file_stream_error.FileStreamError,
  arg: String,
) -> HeadError {
  case err {
    file_stream_error.Eisdir -> IsDirError(arg)
    file_stream_error.Enoent -> NoEntryError(arg)
    _ -> UnknownError
  }
}

fn print_steam(
  stream: file_stream.FileStream,
  lines: Option(Int),
  bytes: Option(Int),
) -> Nil {
  case bytes {
    Some(b) ->
      case stream |> file_stream.read_bytes(b) {
        Error(err) -> err |> debug
        Ok(arr) ->
          case arr |> bit_array.to_string {
            // TODO: エラーの場合読めるところまで読む
            Error(_) -> Nil
            Ok(s) -> s |> io.print
          }
      }
    None ->
      iterator.repeatedly(fn() {
        case stream |> file_stream.read_line {
          Error(file_stream_error.Eof) -> Error(file_stream_error.Eof)
          Error(err) -> Error(err) |> io.debug
          Ok(s) -> Ok(s |> io.print)
        }
      })
      |> iterator.take(option.unwrap(lines, 10))
      |> iterator.take_while(fn(r) { r |> result.is_ok })
      |> iterator.run
  }
}

fn debug(term: anything) -> Nil {
  term |> io.debug |> fn(_) { Nil }
}

pub fn main() {
  case argv.load().arguments |> parse_args {
    Error(err) -> err |> error_message |> io.println
    Ok(args) -> args |> run
  }
}
