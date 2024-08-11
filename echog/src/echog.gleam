import argv
import gleam/io
import gleam/list
import gleam/string

pub fn main() {
  case argv.load().arguments {
    [] -> help()
    args -> args |> parse_args |> run
  }
}

fn help() {
  io.println("echog")
}

type Args {
  Args(omit_newline: Bool, inputs: List(String))
}

fn parse_args(args: List(String)) -> Args {
  let omit_newline_flag = "-n"
  let omit_newline = list.contains(args, omit_newline_flag)
  let inputs = case omit_newline {
    True -> list.filter(args, fn(x) { x != omit_newline_flag })
    False -> args
  }
  Args(omit_newline, inputs)
}

fn run(args: Args) {
  let output = string.join(args.inputs, " ")
  case args.omit_newline {
    True -> io.print(output)
    False -> io.println(output)
  }
}
