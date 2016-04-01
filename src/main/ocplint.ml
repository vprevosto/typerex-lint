


(* Some globals *)
let project_dir = ref ""

let usage_msg =
  let name = Filename.basename Sys.argv.(0) in
  String.concat "\n" [
    "Usage:";
    Printf.sprintf "   %s [OPTIONS] --project DIR" name;
    "";
  ]

let arg_spec = Arg.align [
    "--project", Arg.String (fun dir ->
        project_dir := dir
      ), "DIR   Give a project dir path";
  ]

let arg_spec = Arg.align arg_spec

let main () =
  Arg.parse arg_spec
    (fun s ->
       Printf.printf "Error: don't know what to do with %s\n%!" s;
       exit 1)
    usage_msg;
  let _reports = Ocplint_actions.scan !project_dir in
  ()

let () =
  main ()