open Parsetree
open Std_utils
module A = Automaton
module AE = Ast_element

let setloc = Match.set_current_location

let both
  = fun (s1, l1) (s2, l2) ->
  if not A.(s1.final && s2.final) then
    []
  else
    let locations =
      List.bind (Option.to_list)
        [Match.get_location l1; Match.get_location l2]
    and merged_matches = {
      l2 with
      Match.substitutions = Substitution.merge
          (Match.get_substitutions l1)
          (Match.get_substitutions l2)
      ;
    }
    in
    List.map (
      fun loc -> Builder.final (),
                 { merged_matches with Match.location = Some loc }
      )
      locations

let rec apply' = fun env state node ->
  if state.A.final then
    [state, env]
  else
    let new_states = List.bind
        (fun (update_loc, trans) ->
           let new_loc =
             if update_loc then
               Some (Match.get_current_location env)
             else
               Match.get_location env
           in
           let env = { env with Match.location = new_loc } in
           (trans env node)
        )
        state.A.transitions
    in
    dispatch new_states node

and apply2 = fun state_bun env expr ->
    match state_bun, expr with
    | A.Final, _ -> [Builder.final (), env]
    | A.Expr (A.Apply (s1, s2)), AE.Expression {
        pexp_desc = Pexp_apply (e1, ["", e2]);
        _
      } ->
      List.product_bind both
        (apply' (setloc e1.pexp_loc env) s1 (AE.Expression e1))
        (apply' (setloc e2.pexp_loc env) s2 (AE.Expression e2))
    | A.Expr (A.Let (bindings_state, expr_state)), AE.Expression {
        pexp_desc = Pexp_let (_, bindings, expr);
        _
      } ->
      let bindings_final_states =
        let states_list =
          Option.map
            (
              List.map2 (fun binding_state binding ->
                  apply' (setloc binding.pvb_loc env) binding_state (AE.Value_binding binding))
                bindings_state
            )
            (List.truncate_as bindings bindings_state)
          |> Option.value []
        in match states_list with
        | [] -> []
        | hd::tl -> List.fold_left (List.product_bind both) hd tl
      in
      List.product_bind both
        (apply' (setloc expr.pexp_loc env) expr_state (AE.Expression expr))
        bindings_final_states
    | A.Expr (A.Ifthenelse (s_if, s_then, None)), AE.Expression {
        pexp_desc = Pexp_ifthenelse (e_if, e_then, None);
        _
      } ->
      List.product_bind both
        (apply' (setloc e_if.pexp_loc env) s_if (AE.Expression e_if))
        (apply' (setloc e_then.pexp_loc env) s_then (AE.Expression e_then))
    | A.Expr (A.Ifthenelse (s_if, s_then, Some s_else)), AE.Expression {
        pexp_desc = Pexp_ifthenelse (e_if, e_then, Some e_else);
        _
      } ->
      List.product_bind both
        (
          List.product_bind both
            (apply' (setloc e_if.pexp_loc env) s_if (AE.Expression e_if))
            (apply' (setloc e_then.pexp_loc env) s_then (AE.Expression e_then))
        )
        (apply' (setloc e_else.pexp_loc env) s_else (AE.Expression e_else))
    | A.Expr (A.Construct None), _ -> [Builder.final (), env]
    | A.Expr (A.Construct (Some expr_state)), AE.Expression {
        pexp_desc = Pexp_construct (_, (Some expr));
        _
      } ->
      apply' (setloc expr.pexp_loc env) expr_state (AE.Expression expr)
    | A.Pattern _, AE.Pattern {
        ppat_loc = l;
        _
      } -> [Builder.final (), setloc l env]
    | A.Value_binding { A.vb_pat; vb_expr; }, AE.Value_binding {
        pvb_pat = pat;
        pvb_expr = expr;
        _
      } ->
      List.product_bind both
        (apply' (setloc expr.pexp_loc env) vb_expr (AE.Expression expr))
        (apply' (setloc pat.ppat_loc env) vb_pat (AE.Pattern pat))
    | _ -> []

and dispatch = fun state_bundles expr ->
  List.bind (fun (state_bun, env) -> apply2 state_bun env expr) state_bundles

let apply name state expr =
  let results = apply'
      (Match.mk name Substitution.empty None expr.pexp_loc)
      state (AE.Expression expr)
  in
  results
