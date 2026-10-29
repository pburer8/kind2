(* This file is part of the Kind 2 model checker.

   Copyright (c) 2015-2019 by the Board of Trustees of the University of Iowa

   Licensed under the Apache License, Version 2.0 (the "License"); you
   may not use this file except in compliance with the License.  You
   may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0 

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
   implied. See the License for the specific language governing
   permissions and limitations under the License. 

*)

module TSys = TransSys
module SM = Map.Make (String)
module HS = HStringSExpr
module SS = Set.Make (String)

let add_as_candidate os_invs sys =
  let _cnt = ref 0 in
  let cnt () =
    _cnt := !_cnt + 1 ;
    !_cnt
  in
  let create_candidate t =
    Property.{
      prop_name = Format.sprintf "%%inv_%i" (cnt ()) ;
      prop_source = Property.Candidate {source = None; report = false} ;
      prop_term = t ;
      prop_status = PropUnknown ;
      prop_kind = Invariant ;
      prop_expr = None;
    }
  in
  let props = List.map create_candidate os_invs in
  let props = props @ (TSys.get_properties sys) in
  TSys.set_subsystem_properties sys (TSys.scope_of_trans_sys sys) props

let sv_key sv = Format.asprintf "%a" StateVar.pp_print_state_var sv

let str = HString.string_of_hstring

(* Identity of a state variable: the same printer the cache writer uses. *)
let sv_key sv = Format.asprintf "%a" StateVar.pp_print_state_var sv

let current_signature sys =
  TSys.state_vars sys
  |> List.fold_left
       (fun m sv -> SM.add (sv_key sv) (StateVar.type_of_state_var sv) m)
       SM.empty

let type_of_sexpr =
  GenericSMTLIBDriver.smtlib_string_sexpr_conv
    .GenericSMTLIBDriver.type_of_sexpr

(* Do all variables of one cached invariant exist, with the same type? *)
type verdict = Keep | Missing of string | Retyped of string

let check_signature cur sigs =
  let rec go = function
    | [] -> Keep
    | HS.List [HS.Atom n; ty] :: rest -> (
      let n = str n in
      match SM.find_opt n cur with
      | None -> Missing n
      | Some t ->
        if Type.equal_types t (type_of_sexpr ty) then go rest else Retyped n)
    | _ -> Missing "<malformed signature>"
  in
  go sigs

(* Walk the stored system and the new one in lockstep, building old->new
   and its inverse. [None] means the two are not related by a renaming. *)
let rec match_sexp ~old_vars ~new_vars st o n =
  match o, n with
  | HS.Atom a, HS.Atom b -> (
    let a = str a and b = str b in
    let sigma, inv = st in
    match SS.mem a old_vars, SS.mem b new_vars with
    | true, true -> (
      match SM.find_opt a sigma, SM.find_opt b inv with
      | None, None -> Some (SM.add a b sigma, SM.add b a inv)
      | Some b', Some a' when b' = b && a' = a -> Some st
      | _ -> None)
    | false, false when a = b -> Some st
    | _ -> None)
  | HS.List os, HS.List ns when List.length os = List.length ns ->
    List.fold_left2
      (fun acc o n ->
         Option.bind acc (fun st -> match_sexp ~old_vars ~new_vars st o n))
      (Some st) os ns
  | _ -> None

(* One simultaneous pass, so a swap x<->y is handled correctly. *)
let rec rename sigma = function
  | HS.Atom a as s -> (
    match SM.find_opt (str a) sigma with
    | Some b -> HS.Atom (HString.mk_hstring b)
    | None -> s)
  | HS.List l -> HS.List (List.map (rename sigma) l)

let head_is name = function
  | HS.List (HS.Atom h :: _) -> str h = name
  | _ -> false

(* Variable names declared in a (system (vars (decl ...)) ...) entry. *)
let old_vars_of = function
  | HS.List (_ :: parts) -> (
    match List.find_opt (head_is "vars") parts with
    | Some (HS.List [_; HS.List decls]) ->
      List.filter_map
        (function
          | HS.List (HS.Atom n :: _) -> Some (str n)
          | _ -> None)
        decls
      |> SS.of_list
    | _ -> SS.empty)
  | _ -> SS.empty

let parse_one s =
  match SExprParser.sexps SExprLexer.main (Lexing.from_string s) with
  | [x] -> Some x
  | _ -> None
  | exception _ -> None

(* ---------- Myers O(ND) diff ---------- *)
type 'a edit = Same of 'a | Del of 'a | Ins of 'a

let myers_diff ~(eq : 'a -> 'a -> bool) (a : 'a array) (b : 'a array)
  : 'a edit list =
  let n = Array.length a and m = Array.length b in
  let max = n + m in
  let off = max in
  let v = Array.make ((2 * max) + 2) 0 in
  let trace = ref [] in
  let found = ref false in
  let d = ref 0 in
  while not !found && !d <= max do
    trace := Array.copy v :: !trace ;
    let k = ref (- !d) in
    while not !found && !k <= !d do
      let kk = !k in
      let x0 =
        if kk = - !d || (kk <> !d && v.(off + kk - 1) < v.(off + kk + 1))
        then v.(off + kk + 1)
        else v.(off + kk - 1) + 1
      in
      let x = ref x0 in
      let y = ref (x0 - kk) in
      while !x < n && !y < m && eq a.(!x) b.(!y) do incr x ; incr y done ;
      v.(off + kk) <- !x ;
      if !x >= n && !y >= m then found := true ;
      k := kk + 2
    done ;
    if not !found then incr d
  done ;
  let trace = Array.of_list (List.rev !trace) in
  let x = ref n and y = ref m and acc = ref [] in
  for dd = !d downto 1 do
    let vd = trace.(dd) in
    let k = !x - !y in
    let prev_k =
      if k = -dd || (k <> dd && vd.(off + k - 1) < vd.(off + k + 1))
      then k + 1 else k - 1
    in
    let prev_x = vd.(off + prev_k) in
    let prev_y = prev_x - prev_k in
    while !x > prev_x && !y > prev_y do
      acc := Same a.(!x - 1) :: !acc ; decr x ; decr y
    done ;
    if !x = prev_x then acc := Ins b.(!y - 1) :: !acc
    else acc := Del a.(!x - 1) :: !acc ;
    x := prev_x ; y := prev_y
  done ;
  while !x > 0 && !y > 0 do
    acc := Same a.(!x - 1) :: !acc ; decr x ; decr y
  done ;
  !acc

(* ---------- Declarations and rename extraction ---------- *)
type decl = { name : string; ty : string; flags : string }
let shape d = d.ty ^ " " ^ d.flags

type var_diff = {
  renamed : (string * string) list;  (* old, new *)
  removed : string list;
  added : string list;
  retyped : (string * string * string) list;
  reflagged : (string * string * string) list;
}

(* Within one changed hunk, pair deletions with insertions of the same
   shape, in order, but only when the counts for that shape are equal. *)
let pair_hunk dels inss =
  let shapes = List.sort_uniq compare (List.map (fun d -> shape d) dels) in
  let renamed, paired_old, paired_new =
    List.fold_left
      (fun (r, po, pn) sh ->
         let ds = List.filter (fun d -> shape d = sh) dels in
         let is = List.filter (fun d -> shape d = sh) inss in
         if List.length ds = List.length is then
           (r @ List.map2 (fun o n -> (o.name, n.name)) ds is,
            po @ ds, pn @ is)
         else (r, po, pn))
      ([], [], []) shapes
  in
  let not_in l x = not (List.memq x l) in
  (renamed,
   List.filter (not_in paired_old) dels,
   List.filter (not_in paired_new) inss)

let diff_vars old_decls new_decls =
  let find n l = List.find_opt (fun d -> d.name = n) l in

  (* Same name on both sides, different type. *)
  let retyped =
    List.filter_map
      (fun o ->
         match find o.name new_decls with
         | Some n when n.ty <> o.ty -> Some (o.name, o.ty, n.ty)
         | _ -> None)
      old_decls
  in

  (* Same name and type, different flags. *)
  let reflagged =
    List.filter_map
      (fun o ->
         match find o.name new_decls with
         | Some n when n.ty = o.ty && n.flags <> o.flags ->
           Some (o.name, o.flags, n.flags)
         | _ -> None)
      old_decls
  in

  let eq a b = a.name = b.name && a.ty = b.ty && a.flags = b.flags in
  let edits =
    myers_diff ~eq (Array.of_list old_decls) (Array.of_list new_decls) in
  let ren = ref [] and rem = ref [] and add = ref [] in

  let flush dels inss =
    (* A name present on both sides is retyped, reflagged or moved,
       never renamed, so keep it out of the pairing. *)
    let dels =
      List.filter (fun d -> find d.name new_decls = None) (List.rev dels) in
    let inss =
      List.filter (fun d -> find d.name old_decls = None) (List.rev inss) in
    let r, d, i = pair_hunk dels inss in
    ren := !ren @ r ;
    rem := !rem @ d ;
    add := !add @ i
  in

  let dels, inss =
    List.fold_left
      (fun (dels, inss) -> function
         | Same _ -> flush dels inss ; ([], [])
         | Del x -> (x :: dels, inss)
         | Ins x -> (dels, x :: inss))
      ([], []) edits
  in
  flush dels inss ;

  { renamed = !ren;
    retyped;
    reflagged;
    removed = List.map (fun d -> d.name) !rem;
    added = List.map (fun d -> d.name) !add }

(* ---------- Reading declarations from the cached system ---------- *)
let rec sexp_str = function
  | HS.Atom a -> str a
  | HS.List l -> "(" ^ String.concat " " (List.map sexp_str l) ^ ")"

let decls_of = function
  | HS.List (_ :: parts) -> (
    match List.find_opt (head_is "vars") parts with
    | Some (HS.List [_; HS.List decls]) ->
      List.filter_map
        (function
          | HS.List (HS.Atom n :: ty :: flags) ->
            Some { name = str n;
                   ty = sexp_str ty;
                   flags = String.concat " " (List.map sexp_str flags) }
          | _ -> None)
        decls
    | _ -> [])
  | _ -> []

(* ---------- Node names ---------- *)
let node_of name =
  match String.index_opt name '.' with
  | Some i when i > 0 -> Some (String.sub name 0 i)
  | _ -> None

let strip_node name =
  match String.index_opt name '.' with
  | Some i -> String.sub name (i + 1) (String.length name - i - 1)
  | None -> name

(* The one node prefix shared by every declaration, if there is exactly one. *)
let node_of_decls decls =
  match List.sort_uniq compare (List.map (fun d -> node_of d.name) decls) with
  | [Some n] -> Some n
  | _ -> None

let rebase ~old_node ~new_node name =
  match node_of name with
  | Some n when n = old_node ->
    new_node
    ^ String.sub name (String.length n) (String.length name - String.length n)
  | _ -> name

(* N.usr.c -> M.usr.c: a change in the node prefix and nothing else. *)
let is_node_only_rename a b =
  node_of a <> node_of b && strip_node a = strip_node b

type node_change = Node_same | Node_renamed of string * string | Node_unknown

let diff_nodes old_decls new_decls =
  match node_of_decls old_decls, node_of_decls new_decls with
  | Some o, Some n -> if o = n then Node_same else Node_renamed (o, n)
  | _ -> Node_unknown

type full_diff = {
  node : node_change;
  sigma : string SM.t;  (* old variable name -> new name, for every old variable *)
  vars : var_diff;      (* reported with old names rebased onto the new node *)
}

let diff_system old_decls new_decls =
  let node = diff_nodes old_decls new_decls in
  let norm =
    match node with
    | Node_renamed (o, n) -> rebase ~old_node:o ~new_node:n
    | _ -> (fun x -> x)
  in
  let old_norm = List.map (fun d -> { d with name = norm d.name }) old_decls in
  let vars = diff_vars old_norm new_decls in
  let renames =
    List.fold_left (fun m (a, b) -> SM.add a b m) SM.empty vars.renamed in
  let sigma =
    List.fold_left
      (fun m d ->
         let nd = norm d.name in
         let target = match SM.find_opt nd renames with Some b -> b | None -> nd in
         SM.add d.name target m)
      SM.empty old_decls
  in
  { node; sigma; vars }

let load_cached_invariants sys cache_file =
  match open_in cache_file with
  | exception Sys_error _ -> sys
  | ic ->
    let sexps =
      try SExprParser.sexps SExprLexer.main (Lexing.from_channel ic)
      with _ -> []
    in
    close_in ic ;
    let system_entries, inv_entries = List.partition (head_is "system") sexps in
    let cur = current_signature sys in

    (* Is the new system the stored one up to a renaming of variables? *)
    let sigma =
      match system_entries, parse_one (NativeInput.structural_form sys) with
      | [old_system], Some new_system -> (
        let old_decls = decls_of old_system and new_decls = decls_of new_system in
        ( match diff_nodes old_decls new_decls with
          | Node_renamed (o, n) -> KEvent.log L_note "Cache: node renamed %s -> %s." o n
          | Node_same | Node_unknown -> () ) ;
        let new_vars = SS.of_list (List.map fst (SM.bindings cur)) in
        match
          match_sexp ~old_vars:(old_vars_of old_system) ~new_vars
            (SM.empty, SM.empty) old_system new_system
        with
        | Some (s, _) -> Some s
        | None ->
          let fd = diff_system old_decls new_decls in
          List.iter (fun (n, o, t) ->
              KEvent.log L_note "Cache: %s changed type %s -> %s" n o t)
            fd.vars.retyped ;
          List.iter (fun (n, o, f) ->
              KEvent.log L_note "Cache: %s changed flags '%s' -> '%s'" n o f)
            fd.vars.reflagged ;
          List.iter (fun (a, b) ->
              KEvent.log L_note "Cache: guessed rename %s -> %s" a b)
            fd.vars.renamed ;
          Some fd.sigma)
      | _ -> None
    in
    ( match sigma with
      | Some s ->
        let renamed = SM.filter (fun a b -> a <> b && not (is_node_only_rename a b)) s in
        if SM.is_empty renamed then
          KEvent.log L_note "Cache: system unchanged."
        else (
          KEvent.log L_note "Cache: %d variable(s) renamed." (SM.cardinal renamed) ;
          SM.iter (fun a b -> KEvent.log L_note "  %s -> %s" a b) renamed
        )
      | None ->
        KEvent.log L_note
          "Cache: system structure differs or is missing; \
           keeping only invariants whose variables still exist." ) ;

    let kept = ref [] and dropped = ref 0 in
    let drop fmt =
      incr dropped ;
      Format.kasprintf (fun s -> KEvent.log L_debug "Cached invariant dropped: %s" s) fmt
    in
    List.iter
      (fun entry ->
         (* Rename first, so the signature check below runs against the
            new names and also validates the types in the new system. *)
         let entry = match sigma with Some s -> rename s entry | None -> entry in
         match entry with
         | HS.List [HS.Atom tag; HS.List sigs; term] when str tag = "inv" -> (
           match check_signature cur sigs with
           | Keep -> (
             try kept := NativeInput.term_of_sexpr term :: !kept
             with e -> drop "cannot parse (%s)" (Printexc.to_string e))
           | Missing v -> drop "%s no longer exists" v
           | Retyped v -> drop "%s changed type" v)
         | _ -> drop "old-format or malformed entry")
      inv_entries ;

    KEvent.log L_note "Cached invariants: %d loaded as candidates, %d dropped."
      (List.length !kept) !dropped ;
    add_as_candidate (List.rev !kept) sys