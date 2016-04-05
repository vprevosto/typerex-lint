open Asttypes
open Parsetree
open Ast_mapper
open Check_types
open Configuration
open Info

let info = {
  name = "Missing Interface";
  details = "Long details";
  cat = Interface;
}

let run config reports sources =
  let mlis =
    List.filter (fun file -> Filename.check_suffix file "mli") sources in
  let mlis = List.map Filename.chop_extension mlis in
  List.iter (fun file ->
      let name = Filename.chop_extension file in
      if not (List.mem name mlis) then
        let msg =
          Printf.sprintf "Missing interface for %S" file in
        Reports.add (Reports.warning Location.none info msg) reports)
    (List.filter (fun file -> Filename.check_suffix file "ml") sources)

let check : Check_types.global_check = { global_run = run; global_info = info }