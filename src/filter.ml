(* Encoded molecules filtering and diversity selection.
   Functionalities:
   - remove training set molecules (or anything too near) from a
     "database" of molecules
     _OR_
   - enforce diversity in a "database" of molecules *)

open Printf

module CLI = Minicli.CLI
module FpMol = Molenc.FpMol
module Utls = Molenc.Utls

module Bstree = struct

  include Bst.Bisec_tree.Make (FpMol)

  let of_list mols =
    create 1 Two_bands (Array.of_list mols)
end

type mode = Filter of string (* file from where to read molecules to exclude *)
          | Diversify

let main () =
  Log.(set_log_level INFO);
  Log.color_on ();
  let argc, args = CLI.init () in
  if argc = 1 then
    begin
      eprintf "usage:\n\
               %s\n  \
               -i <filename>: molecules to filter (\"database\")\n  \
               -o <filename>: output file\n  \
               [-t <float>]: Tanimoto threshold (default=1.0)\n  \
               [-e <filename>]: molecules to exclude from the ones to filter\n  \
               [-v]: verbose mode\n"
        Sys.argv.(0);
      exit 1
    end;
  let input_fn = CLI.get_string ["-i"] args in
  let output_fn = CLI.get_string ["-o"] args in
  let filtered_out_fn = output_fn ^ ".discarded" in
  let threshold = CLI.get_float_def ["-t"] args 1.0 in
  assert(threshold >= 0.0 && threshold <= 1.0);
  let verbose = CLI.get_set_bool ["-v"] args in
  let mode = match CLI.get_string_opt ["-e"] args with
    | None -> Diversify
    | Some fn -> Filter fn in
  CLI.finalize ();
  let threshold_distance = 1.0 -. threshold in
  let read_count = ref 0 in
  let filtered_count = ref 0 in
  match mode with
  | Diversify -> assert(false)
  | Filter train_fn ->
    let mols_to_exclude = FpMol.molecules_of_file train_fn in
    let exclude_set = Bstree.of_list mols_to_exclude in
    Utls.with_out_file output_fn (fun out ->
        Utls.with_out_file filtered_out_fn (fun err_out ->
            Utls.iteri_on_lines_of_file input_fn (fun i line ->
                let mol = FpMol.parse_one i line in
                let _nearest_train_mol, nearest_d =
                  Bstree.nearest_neighbor mol exclude_set in
                if verbose then Log.info "d: %f" nearest_d;
                if nearest_d > threshold_distance then
                  fprintf out "%s\n" line (* keep it *)
                else
                  begin
                    fprintf err_out "%s\n" line; (* discard it *)
                    incr filtered_count
                  end;
                incr read_count
              )
          )
      );
    Log.info "read %d from %s" !read_count input_fn;
    Log.info "discarded %d in %s" !filtered_count filtered_out_fn

let () = main ()
