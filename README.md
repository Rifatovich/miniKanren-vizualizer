## qt/qml vizualizer placed in root folder and can be opened in Qt Creator using `Import Project -> Git Clone`

`miniKanren.js` contains current verison of unicanren translated into JavaScript

----
## unicanren placed in folder `unicanren`, its fork of `github.com/Kakadu/unicanren`
- Call of appendo happens in the `unicanren/bin/main.ml` file
- Tree builds in `let eval ?(trace_svars = false) ?(trace_uni = false) ?(trace_calls = false)`
function, using `Js.Unsafe.global##` calls in `unicanren/lib/lib.ml`

### How to translate unicanren into javascript:
* `cd unicanren`
* `dune build ./bin/main.bc.js`

Then content of `unicanren/_build/default/bin/main.bc.js`  is referenced in Qt project, so building 
OCaml library is required for successful compilation of Qt/QML frontend.

## License
[MIT License](LICENSE)
