import argv
import gleam/io
import gleam/list
import gleam/string

const omit_newline_flag = "-n"

pub fn main() {
  case argv.load().arguments {
    [] -> help()
    args -> run(args)
  }
}

fn help() {
  io.println("echog")
}

fn run(args: List(String)) {
  let omit_newline = list.contains(args, omit_newline_flag)

  let outputs = case omit_newline {
    True -> list.take_while(args, fn(x) { x != omit_newline_flag })
    False -> args
  }

  let output = string.join(outputs, " ")
  case omit_newline {
    True -> io.print(output)
    False -> io.println(output)
  }
}
