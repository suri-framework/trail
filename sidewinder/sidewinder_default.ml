open Riot
open Html

let mount ~path () =
  let id = "sidewinder-component-" ^ Int.to_string (Crypto.Random.int ()) in
  div
    ~children:
      [
        div ~id ~children:[] ();
        script ~type_:"module"
          ~children:
            [
              Format.sprintf
                {|
                                                                                                  import * as SidewinderComponent from "/@sidewinder_static/sidewinder_web_runtime.mjs";
                                                                                                        SidewinderComponent.spawn(%S, %S);
                                                                                                              |}
                id path
              |> string;
            ]
          ();
      ]
    ()
