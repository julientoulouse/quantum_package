let test_module () = 
  let atom = Element.of_string "Cobalt" in
  Printf.printf "%s %d\n" (Element.to_string atom) (Element.charge atom)
;;

test_module ();;