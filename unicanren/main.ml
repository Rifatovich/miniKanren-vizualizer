open Js_of_ocaml
open Format

module Term = struct
  type t =
    | Var of string
    | Symbol of string
    | Cons of t * t
    | Nil

  let cons a b = Cons (a, b)
  let symbol s = Symbol s
  let var n = Var n

  let rec pp ppf = function
    | Var s -> fprintf ppf "%s" s
    | Symbol s -> fprintf ppf "'%s" s
    | Cons (l, r) -> fprintf ppf "(cons %a %a)" pp l pp r
    | Nil -> fprintf ppf "'()"
  ;;
end

open Term

type goal =
  | Unify of Term.t * Term.t
  | Conj of goal list
  | Conde of goal list (* TODO: make non-empty list here *)
  | Fresh of string * goal
  | Call of string * Term.t list
  | TraceSVars of string list

(** Goal smart constructor(s) *)

let fresh = List.fold_right (fun n acc -> Fresh (n, acc))

let pp_goal =
  let rec helper ppf = function
    | Unify (l, r) -> fprintf ppf "(== %a %a)" Term.pp l Term.pp r
    | Conde [] | Conj [] -> assert false
    | Conde xs ->
      fprintf ppf "(conde [ %a ])" (pp_print_list ~pp_sep:pp_print_space helper) xs
    | Conj xs -> pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf " && ") helper ppf xs
    | Fresh (s, g) -> fprintf ppf "(fresh (%s) %a)" s helper g
    | Call (name, args) ->
      fprintf ppf "(%s %a)" name (pp_print_list ~pp_sep:pp_print_space Term.pp) args
    | TraceSVars _ -> fprintf ppf "(trace...)"
  in
  helper
;;

module Subst = struct
  include Map.Make (Int)

  let pp val_pp ppf s =
    Format.fprintf ppf "@[<v>";
    iter (fun n -> Format.fprintf ppf "_.%d -> @[%a@]@ %!" n val_pp) s;
    Format.fprintf ppf "@]"
  ;;
end

module Value = struct
  type t =
    | Var of int
    | Symbol of string
    | Cons of t * t
    | Nil

  let var x = Var x
  let symbol s = Symbol s
  let cons x y = Cons (x, y)
  let nil = Nil
  let _0 = symbol "0"
  let _1 = symbol "1"

  let pp =
    let need_par = function
      | Symbol _ | Var _ | Nil -> false
      | Cons (_, _) -> true
    in
    let par p ppf x = if need_par x then fprintf ppf "(%a)" p x else p ppf x in
    let rec helper ppf = function
      | Var n -> Format.fprintf ppf "_.%d" n
      | Symbol s -> Format.fprintf ppf "'%s" s
      | Cons (l, r) -> Format.fprintf ppf "cons %a %a" (par helper) l (par helper) r
      | Nil -> fprintf ppf "nil"
    in
    par helper
  ;;

  let rec walk subst : t -> t = function
    | Var v ->
      (match Subst.find v subst with
      | exception Not_found -> Var v
      | t2 -> walk subst t2)
    | Symbol s -> Symbol s
    | Cons (l, r) -> cons (walk subst l) (walk subst r)
    | Nil -> Nil
  ;;

  let ppw s ppf x = pp ppf (walk s x)
end

let rec unify acc x y =
  (* printf "Calling unify of `%a` and `%a`\n%!" Value.pp x Value.pp y; *)
  match Value.walk acc x, Value.walk acc y with
  | Value.Var n, Value.Var m when n = m -> Some acc
  | Var n, (Var _m as rhs) -> Some (Subst.add n rhs acc)
  | Symbol m, Symbol n when n = m -> Some acc
  | Symbol _, Symbol _ -> None
  | Nil, Nil -> Some acc
  | rhs, Var n | Var n, rhs -> Some (Subst.add n rhs acc)
  | Cons (l1, r1), Cons (l2, r2) ->
    let open Base.Option in
    unify acc l1 l2 >>= fun acc -> unify acc r1 r2
  | Symbol _, Cons (_, _)
  | Cons (_, _), Symbol _
  | Nil, Cons (_, _)
  | Cons (_, _), Nil
  | Symbol _, Nil
  | Nil, Symbol _ -> None
;;

module VarsMap = struct
  include Map.Make (String)

  let pp onval ppf s =
    Format.fprintf ppf "@[<v>";
    iter (fun n -> Format.fprintf ppf "%s -> @[%a@]; %!" n onval) s;
    Format.fprintf ppf "@]"
  ;;
end

(* State is syntax variables + subject variables
  TODO: map for relations
*)
type subst = Value.t Subst.t

module State = struct
  type t =
    { svars : Value.t VarsMap.t
    ; lvars : subst
    ; rels : (string * string list * goal) VarsMap.t
    }

  let empty = { svars = VarsMap.empty; lvars = Subst.empty; rels = VarsMap.empty }
  let add_var name t st = { st with svars = VarsMap.add name t st.svars }
  let ( --> ) = add_var
  let add_var_logic idx t st = { st with lvars = Subst.add idx t st.lvars }
  let ( ->> ) = add_var_logic
  let add_rel name args g st = { st with rels = VarsMap.add name (name, args, g) st.rels }
end

type st = State.t

type error =
  [ `UnboundSyntaxVariable of string
  | `UnboundRelation of string
  | `BadArity
  ]

let pp_error ppf = function
  | `BadArity -> fprintf ppf "bad arity"
  | `UnboundSyntaxVariable s -> fprintf ppf "Unbound variable: %s" s
  | `UnboundRelation s -> fprintf ppf "Unbound realtion: %s" s
;;

let failwiths fmt = kasprintf failwith fmt

module StateMonad : sig
  type ('a, 'b) t

  val fail : error -> ('a, 'b) t
  val return : 'b -> ('a, 'b) t
  val ( >>= ) : ('a, 'b) t -> ('b -> ('a, 'c) t) -> ('a, 'c) t
  val ( <*> ) : ('st, 'a -> 'b) t -> ('st, 'a) t -> ('st, 'b) t
  val ( >>| ) : ('st, 'a) t -> ('a -> 'b) -> ('st, 'b) t

  module Syntax : sig
    val ( let* ) : ('a, 'b) t -> ('b -> ('a, 'c) t) -> ('a, 'c) t
  end

  val run : ('st, 'r) t -> 'st -> ('r, error) Result.t
  val read : ('a, 'a) t
  val lookup_var_syntax : string -> (st, Value.t option) t
  val lookup_var_logic : int -> (st, Value.t option) t
  val put : st -> (st, unit) t
  val put_svars : Value.t VarsMap.t -> (st, unit) t
  val put_lvars : subst -> (st, unit) t

  module List : sig
    val mapm : ('a -> ('st, 'b) t) -> 'a list -> ('st, 'b list) t

    val foldlm
      :  ('acc -> 'a -> ('st, 'acc) t)
      -> ('st, 'acc) t
      -> 'a list
      -> ('st, 'acc) t

    val foldl2m
      :  on_fail:('st, 'acc) t
      -> ('acc -> 'a -> 'b -> ('st, 'acc) t)
      -> ('st, 'acc) t
      -> 'a list
      -> 'b list
      -> ('st, 'acc) t
  end
end = struct
  type ('st, 'b) t = 'st -> ('st * 'b, error) Result.t

  let fail e _st = Result.error e
  let return x st = Result.ok (st, x)
  let ( >>| ) x f st = Result.map (fun (st, x) -> st, f x) (x st)

  let bind x f st =
    match x st with
    | Result.Ok (st, r) -> f r st
    | Error e -> Error e
  ;;

  let ( <*> ) f x st =
    Result.bind (f st) (fun (st, f) ->
        Result.bind (x st) (fun (st, x) -> Result.Ok (st, f x)))
  ;;

  let ( >>= ) = bind
  let run : (_, _) t -> _ -> _ = fun m st -> Result.map snd (m st)

  module Syntax = struct
    let ( let* ) = bind
  end

  let read : 'st. ('st, 'st) t = fun st -> Result.Ok (st, st)

  let lookup_var_syntax : string -> (st, Value.t option) t =
   fun name ->
    let open Syntax in
    let* { State.svars; _ } = read in
    return (VarsMap.find_opt name svars)
 ;;

  let lookup_var_logic : int -> (st, Value.t option) t =
   fun name ->
    let open Syntax in
    let* { State.lvars; _ } = read in
    return (Subst.find_opt name lvars)
 ;;

  let put st0 _st = return () st0

  let put_svars svars =
    let open Syntax in
    let* st = read in
    put { st with State.svars }
  ;;

  let put_lvars map =
    let open Syntax in
    let* st = read in
    put { st with State.lvars = map }
  ;;

  module List = struct
    let rec mapm f = function
      | [] -> return []
      | x :: xs -> return List.cons <*> f x <*> mapm f xs
    ;;

    let rec foldlm f acc = function
      | [] -> acc
      | x :: xs -> foldlm f (acc >>= fun acc -> f acc x) xs
    ;;

    let foldl2m :
          'st 'b 'acc.
          on_fail:('st, 'acc) t
          -> ('acc -> 'a -> 'b -> ('st, 'acc) t)
          -> ('st, 'acc) t
          -> 'a list
          -> 'b list
          -> ('st, 'acc) t
      =
     fun ~on_fail f acc xs ys ->
      let rec helper acc = function
        | [], [] -> acc
        | x :: xs, y :: ys -> helper (acc >>= fun acc -> f acc x y) (xs, ys)
        | _ -> on_fail
      in
      helper acc (xs, ys)
   ;;
  end
end

type 'a state = (st, 'a) StateMonad.t

module Stream = struct
  type 'a t =
    | Nil
    | Cons of 'a * 'a t Lazy.t
    | Thunk of 'a t Lazy.t

  let rec pp ppf = function
    | Nil -> fprintf ppf "Nil"
    | Cons (_, (lazy tl)) -> fprintf ppf "(Cons (_, %a))" pp tl
    | Thunk _ -> fprintf ppf "(Thunk _)"
  ;;

  let nil = Nil
  let return x = Cons (x, lazy Nil)
  let cons x xs = Cons (x, xs)
  let from_fun zz = Thunk (lazy (zz ()))

  let force = function
    | Thunk (lazy zz) -> zz
    | xs -> xs
  ;;

  let rec mplus : 'a. 'a t -> 'a t -> 'a t =
   fun x y ->
    (* printf "Stream.mplus of `%a` and `%a`\n%!" pp x pp y; *)
    match x, y with
    | Nil, _ -> y
    | Thunk l, r -> mplus r (Lazy.force l)
    | Cons (x, l), r -> Cons (x, lazy (mplus r (Lazy.force l)))
 ;;

  let rec bind s f =
    match s with
    | Nil -> Nil
    | Cons (x, s) -> mplus (f x) (from_fun (fun () -> bind (Lazy.force s) f))
    | Thunk zz -> from_fun (fun () -> bind (Lazy.force zz) f)
  ;;

  let from_funm : (unit -> 'a t state) -> 'a t state =
   fun f ->
    let open StateMonad in
    (* Bullshit ? *)
    return () >>= fun () -> f ()
 ;;

  (* TODO: I think we need monad transformer *)
  let rec bindm : 'a 'b. 'a t state -> ('a -> 'b t state) -> 'b t state =
   fun s f ->
    let open StateMonad in
    let open StateMonad.Syntax in
    let* init = s in
    match init with
    | Nil -> return Nil
    | Cons (x, s) ->
      let* l = f x in
      (* Bullshit ? *)
      let* r = from_funm (fun () -> bindm (return @@ Lazy.force s) f) in
      return @@ mplus l r
    | Thunk zz ->
      (* Bullshit ? *)
      from_funm (fun () -> bindm (return (Lazy.force zz)) f)
 ;;

  let take ?(n = -1) =
    let rec helper n = function
      | Nil -> []
      | _ when n = 0 -> []
      | Cons (s, (lazy tl)) -> s :: helper (n - 1) tl
      | Thunk (lazy zz) -> helper n zz
    in
    helper n
  ;;
end

let next_logic_var =
  let last = ref 10 in
  fun () ->
    incr last;
    !last
;;

let ender x =
  Js.Unsafe.global##.endf();
  x
;;

let eval ?(trace_svars = false) ?(trace_uni = false) ?(trace_calls = false) =
  let open State in
  let open StateMonad in
  let open StateMonad.Syntax in
  let rec eval root : (st, subst Stream.t) StateMonad.t =
    match root with
    | TraceSVars xs ->
      Js.Unsafe.global##.anyf("TraceSVars");
      let* { svars; lvars = subst } = read in
      if trace_svars
      then
        Format.printf
          "  TRACING: %a\n%!"
          (pp_print_list ~pp_sep:pp_print_space (fun ppf name ->
               fprintf
                 ppf
                 "%s = %a;"
                 name
                 Value.pp
                 (Value.walk subst (VarsMap.find name svars))))
          xs;
      return (Stream.return subst)
    | Unify (l, r) ->
      Js.Unsafe.global##.unifyf([l, r]);
      let* l = eval_term l in
      let* r = eval_term r in
      let* ({ State.lvars } as st) = read in
      let ppw = Value.ppw lvars in
      ender (match unify lvars l r with
      | None ->
        if trace_uni then printf "\tUni-FAILED of `%a` and `%a`\n" ppw l ppw r;
        return Stream.nil
      | Some subst2 ->
        if trace_uni then printf "\tUnificated `%a` and `%a`\n" ppw l ppw r;
        let* () = put { st with lvars = subst2 } in
        return (Stream.return subst2))
    | Conde [] -> assert false
    | Conde (x :: xs) ->
      Js.Unsafe.global##.anyf("||");
      let* st = read in
      List.foldlm
        (fun acc y ->
          let* () = put st in
          return (Stream.mplus acc) <*> eval y)
        (eval x)
        xs
    | Conj [] -> assert false
    | Conj [ x ] -> 
      Js.Unsafe.global##.anyf("&&");
      eval x
    | Conj (x :: xs) ->
      Js.Unsafe.global##.anyf("&&");
      let* st = read in
      ender (Stream.bindm (eval x) (fun subst ->
          put { st with lvars = subst } >>= fun () -> eval (Conj xs)))
    | Fresh (name, rhs) ->
      Js.Unsafe.global##.freshf(name);
      let* st = read in
      let term = Value.var (next_logic_var ()) in
      let svars = VarsMap.add name term st.State.svars in
      let* () = put { st with svars } in
      Stream.from_funm (fun () -> eval rhs)
    | Call (fname, args) ->
      Js.Unsafe.global##.callf([fname, args]);
      let* st = read in
      (match VarsMap.find fname st.rels with
      | exception Not_found -> fail (`UnboundRelation fname)
      | _, formal_args, body ->

        assert (Stdlib.List.length formal_args = Stdlib.List.length args);
        (* TODO: let's try to create a new set of syntax variables *)
        let* walked_args =
          List.mapm (fun t -> eval_term t >>| Value.walk st.lvars) args
        in
        let* new_svars =
          List.foldl2m
            (fun acc name v -> return (VarsMap.add name v acc))
            (return VarsMap.empty)
            formal_args
            walked_args
            ~on_fail:(fail `BadArity)
        in
        if trace_calls
        then (
          printf
            "args_itself = [ %a ]\n%!"
            (VarsMap.pp (fun ppf t -> Value.pp ppf (Value.walk st.lvars t)))
            new_svars;
          printf
            "old_svars = [ %a ]\n%!"
            (VarsMap.pp (fun ppf t -> Value.pp ppf (Value.walk st.lvars t)))
            st.svars);
        let new_svars =
          VarsMap.merge
            (fun _k old new_ ->
              match old, new_ with
              | _, Some n -> Some n
              | None, None -> assert false
              | Some n, None -> Some n)
            st.svars
            new_svars
        in
        if trace_calls
        then
          printf
            "new_svars = [ %a ]\n%!"
            (VarsMap.pp (fun ppf t -> Value.pp ppf (Value.walk st.lvars t)))
            new_svars;
        let* () = put { st with svars = new_svars } in
        if trace_calls
        then
          printf
            "\027[0;31mCalling `%s %a`\027[0m\n%!"
            fname
            (pp_print_list ~pp_sep:pp_print_space Value.pp)
            walked_args;
        eval body >>= fun x -> put_svars st.svars >>= fun () -> return x)
    and eval_term = function
    | Nil -> return Value.Nil
    | Symbol s -> return (Value.symbol s)
    | Cons (l, r) -> return Value.cons <*> eval_term l <*> eval_term r
    | Var s ->
      let* next = lookup_var_syntax s in
      (match next with
      | None -> fail (`UnboundSyntaxVariable s)
      | Some t2 -> return t2)
  in eval
;;

let run_optimistically
    ?(trace_svars = false)
    ?(trace_uni = false)
    ?(trace_calls = false)
    g
    st
  =
  printf "\nRunning: %a\n" pp_goal g;
  match StateMonad.run (eval ~trace_svars ~trace_uni ~trace_calls g) st with
  | Result.Ok r -> Stream.take ~n:(-1) r
  | Result.Error e -> failwiths "Error: %a" pp_error e
;;

let default_env = State.empty

let rec build_num n =
  let open Term in
  if n mod 2 = 1
  then Cons (Symbol "1", build_num ((n - 1) / 2))
  else if n = 0
  then Nil
  else (
    let () = assert (n mod 2 = 0) in
    Cons (Symbol "0", build_num (n / 2)))
;;

let default_env =
  let open Term in
  let ( == ) a b = Unify (a, b) in
  let _0 = Symbol "0" in
  let _1 = Symbol "1" in
  default_env
  |> State.add_rel
       "poso"
       [ "n" ]
       (fresh [ "a"; "d" ] (Unify (Var "n", Cons (Var "a", Var "d"))))
  |> State.add_rel
       "gt1o"
       [ "n" ]
       (fresh
          [ "a"; "ad"; "dd" ]
          (Unify (var "n", cons (var "a") (cons (var "ad") (var "dd")))))
  |> State.add_rel
       "full-addero"
       [ "b"; "x"; "y"; "r"; "c" ]
       (let b, x, y, r, c = Var "b", Var "x", Var "y", Var "r", Var "c" in
        Conde
          [ Conj [ _0 == b; _0 == x; _0 == y; _0 == r; _0 == c ]
          ; Conj [ _1 == b; _0 == x; _0 == y; _1 == r; _0 == c ]
          ; Conj [ _0 == b; _1 == x; _0 == y; _1 == r; _0 == c ]
          ; Conj [ _1 == b; _1 == x; _0 == y; _0 == r; _1 == c ]
          ; Conj [ _0 == b; _0 == x; _1 == y; _1 == r; _0 == c ]
          ; Conj [ _1 == b; _0 == x; _1 == y; _0 == r; _1 == c ]
          ; Conj [ _0 == b; _1 == x; _1 == y; _0 == r; _1 == c ]
          ; Conj [ _1 == b; _1 == x; _1 == y; _1 == r; _1 == c ]
          ])
  |> State.add_rel
       "addero"
       [ "d"; "n"; "m"; "r" ]
       (let d, n, m, r, a, c = Var "d", Var "n", Var "m", Var "r", Var "a", Var "c" in
        Conde
          [ Conj [ _0 == d; Nil == m; n == r ]
          ; Conj [ _0 == d; Nil == n; m == r; Call ("poso", [ m ]) ]
          ; Conj [ _1 == d; Nil == m; Call ("addero", [ _0; n; cons _1 Nil; r ]) ]
          ; Conj
              [ _1 == d
              ; Nil == n
              ; Call ("poso", [ m ])
              ; Call ("addero", [ _0; m; cons _1 Nil; r ])
              ]
          ; Conj
              [ cons _1 Nil == n
              ; cons _1 Nil == m (* ; TraceSVars [ "d"; "n"; "m"; "r" ] *)
              ; fresh
                  [ "a"; "c" ]
                  (Conj [ r == cons a c; Call ("full-addero", [ d; _1; _1; a; c ]) ])
              ]
          ; Conj
              [ cons _1 Nil == n (* ; TraceSVars [ "d"; "m"; "r" ] *)
              ; Call ("gen-addero", [ d; n; m; r ])
              ]
          ; Conj
              [ cons _1 Nil == m
              ; Call ("gt1o", [ n ])
              ; Call ("gt1o", [ r ])
              ; Call ("addero", [ d; cons _1 Nil; n; r ])
              ]
          ; Conj [ Call ("gt1o", [ n ]); Call ("gen-addero", [ d; n; m; r ]) ]
          ])
  |> State.add_rel
       "gen-addero"
       [ "d"; "n"; "m"; "r" ]
       (fresh
          [ "u"; "b"; "c"; "e"; "x"; "y"; "z" ]
          (* TODO: renaming b -> v kind of helps but maybe there is an issue with clashing names somewhere else *)
          (Conj
             [ cons (var "u") (var "x") == var "n"
             ; cons (var "b") (var "y") == var "m"
             ; Call ("poso", [ Var "y" ])
             ; cons (var "c") (var "z") == var "r"
             ; Call ("poso", [ Var "z" ])
             ; TraceSVars [ "b" ]
             ; Call ("full-addero", [ Var "d"; Var "u"; Var "b"; Var "c"; Var "e" ])
             ; TraceSVars [ "c"; "e" ]
             ; Call ("addero", [ Var "e"; Var "x"; Var "y"; Var "z" ])
             ]))
  |> State.add_rel
       "pluso"
       [ "n"; "m"; "k" ]
       (Call ("addero", [ _0; Var "n"; Var "m"; Var "k" ]))
;;



let () = Format.set_margin 1000
let () = Format.set_max_indent 100

let pp_colored fmt =
  Format.printf "\027[0;35m";
  Format.kfprintf (fun ppf -> Format.fprintf ppf "\027[0m") fmt
;;

let pp_magenta ppf = pp_colored Format.std_formatter ppf
let __ () = pp_magenta "%d" 1
let __ () = pp_magenta "%s" "a"


let appendo_body =
  Conde
    [ Conj [ Unify (Var "xs", Nil); Unify (Var "ys", Var "xys") ]
    ; Fresh
        ( "h"
        , Fresh
            ( "tmp"
            , Fresh
                ( "tl"
                , Conj
                    [ Unify (Cons (Var "h", Var "tl"), Var "xs")
                    ; Unify (Cons (Var "h", Var "tmp"), Var "xys")
                    ; Call ("appendo", [ Var "tl"; Var "ys"; Var "tmp" ])
                    ] ) ) )
    ]
;;

let run_appendo () =
  let goal =
    Call
      ( "appendo"
      , [ Cons (Symbol "a", Cons (Symbol "b", Nil)); Cons (Symbol "c", Cons (Symbol "d", Nil)); Var "xys" ]
      )
  in
  let env =
    State.(
      empty |> "xys" --> Var 10 |> add_rel "appendo" [ "xs"; "ys"; "xys" ] appendo_body)
  in
  run_optimistically goal env
  |> fun xs ->
  Format.printf "@[<v>";
  List.iter (fun st -> Format.printf "@[Answer: %a@]\n" (Value.ppw st) (Value.var 10)) xs;
  Format.printf "@]%!"
;;


let () =
  Js.Unsafe.global##.jscode := (object%js
    method runAppendo = run_appendo
  end)
