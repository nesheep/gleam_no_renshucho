import argv
import file_streams/file_stream
import file_streams/file_stream_error
import gleam/int
import gleam/io
import gleam/list
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

  use filename <- list.each(args)

  case file_stream.open_read(filename) {
    Error(err) -> print_err(err, filename)
    Ok(stream) -> {
      print_filesteam(stream, number)
      file_stream.close(stream)
      |> result.map_error(io.debug)
      |> result.unwrap(Nil)
    }
  }
}

fn print_err(err: file_stream_error.FileStreamError, filename: String) {
  case err {
    file_stream_error.Eisdir -> filename <> " is a directory"
    file_stream_error.Enoent -> filename <> " no such file or directory"
    _ -> "unknown error"
  }
  |> io.println
}

fn print_filesteam(stream: file_stream.FileStream, number: Bool) {
  print_filesteam_loop(stream, number, 1)
}

fn print_filesteam_loop(stream: file_stream.FileStream, number: Bool, l: Int) {
  case file_stream.read_line(stream) {
    Error(file_stream_error.Eof) -> Nil
    Error(err) -> Error(err) |> result.map_error(io.debug) |> result.unwrap(Nil)
    Ok(line) -> {
      io.print(case number {
        True -> {
          let l_str = int.to_string(l)
          string.repeat(" ", 6 - string.length(l_str)) <> l_str <> "  " <> line
        }
        False -> line
      })
      print_filesteam_loop(stream, number, l + 1)
    }
  }
}
