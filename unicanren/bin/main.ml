open Js_of_ocaml
open Unicanren.Lib
open Unicanren.Test_numbers

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
      , [ Cons (Symbol "a", Cons (Symbol "b", Nil))
        ; Cons (Symbol "c", Cons (Symbol "d", Nil))
        ; Var "xys"
        ] )
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
  Js.Unsafe.global##.jscode
    := object%js
         method runAppendo = run_appendo
       end
;;
