import argv
import file_streams/file_stream
import file_streams/file_stream_error
import gleam/int
import gleam/io
import gleam/result
import gleam/string
import glint

pub fn main() {
  glint.new()
  |> glint.with_name("catg")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.global_help("Gleam cat")
  |> glint.add(at: [], do: run())
  |> glint.run(argv.load().arguments)
}

fn run() -> glint.Command(Nil) {
  use number <- glint.flag(glint.bool_flag("number"))
  use _, args, flags <- glint.command()
  let number = number(flags) |> result.unwrap(False)
  print_files(args, number, 1)
}

fn print_files(files: List(String), number: Bool, start: Int) {
  case files {
    [] -> Nil
    [filename, ..rest] -> {
      let last = case file_stream.open_read(filename) {
        Error(err) -> print_err(err, filename) |> fn(_) { start - 1 }
        Ok(stream) -> {
          let last = print_filesteam(stream, number, start)
          file_stream.close(stream)
          |> result.map_error(io.debug)
          |> fn(_) { last }
        }
      }
      print_files(rest, number, last + 1)
    }
  }
}

fn print_err(err: file_stream_error.FileStreamError, filename: String) {
  io.print("catg: ")
  io.println(case err {
    file_stream_error.Eisdir -> filename <> ": Is a directory"
    file_stream_error.Enoent -> filename <> ": No such file or directory"
    _ -> "unknown error"
  })
}

fn print_filesteam(stream: file_stream.FileStream, number: Bool, n: Int) -> Int {
  case file_stream.read_line(stream) {
    Error(file_stream_error.Eof) -> n - 1
    Error(err) -> err |> io.debug |> fn(_) { n - 1 }
    Ok(line) -> {
      io.print(case number {
        True -> n |> int.to_string |> format_with_number(line)
        False -> line
      })
      print_filesteam(stream, number, n + 1)
    }
  }
}

fn format_with_number(n: String, line: String) -> String {
  string.repeat(" ", 6 - string.length(n)) <> n <> "  " <> line
}
