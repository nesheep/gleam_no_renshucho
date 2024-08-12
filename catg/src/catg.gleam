import argv
import file_streams/file_stream
import file_streams/file_stream_error
import gleam/io
import gleam/list
import gleam/result
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
  use _, args, _ <- glint.command()
  use filename <- list.each(args)

  case file_stream.open_read(filename) {
    Error(err) -> print_err(err, filename)
    Ok(stream) -> {
      print_filesteam(stream)
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

fn print_filesteam(stream: file_stream.FileStream) {
  case file_stream.read_line(stream) {
    Error(file_stream_error.Eof) -> Nil
    Error(err) -> Error(err) |> result.map_error(io.debug) |> result.unwrap(Nil)
    Ok(line) -> {
      io.print(line)
      print_filesteam(stream)
    }
  }
}
