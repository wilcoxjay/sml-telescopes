functor Telescope (L : TELESCOPE_LABEL) :> TELESCOPE where type Label.t = L.t =
struct
  structure Label = L
  structure D = SplayDict (structure Key = L)

  type label = L.t

  exception Absent

  structure Internal =
  struct
    type 'a telescope = L.t list * 'a D.dict

    val isEmpty =
      fn ([], _) => true
       | _ => false

    val empty = ([], D.empty)

    fun snoc (list, dict) lbl x =
      if D.member dict lbl then
        raise Fail ("snoc: duplicates " ^ L.toString lbl)
      else
        (lbl :: list, D.insert dict lbl x)

    fun cons lbl x (list, dict) =
      if D.member dict lbl then
        raise Fail ("cons: duplicates " ^ L.toString lbl)
      else
        (list @ [lbl], D.insert dict lbl x)

    fun append (list1, dict1) (list2, dict2) =
      let
        val dict = D.union dict1 dict2 (fn (l, _, _) => raise Fail ("append: duplicates " ^ L.toString l))
      in
        (list2 @ list1, dict)
      end

    fun lookup (list, dict) lbl =
      D.lookup dict lbl handle _ => raise Absent

    fun find (list, dict) lbl =
      D.find dict lbl

    fun map f (list, dict) =
      (list, D.map f dict)

    fun modify lbl f (list, dict) =
      let
        val (_, _, dict') = D.operate dict lbl (fn _ => raise Absent) f
      in
        (list, dict')
      end

    fun modifyAfter lbl f (list, dict) =
      let
        fun go [] dict = dict
          | go (l :: ls) dict =
              if L.eq (l, lbl) then
                dict
              else
                let
                  val a = D.lookup dict l
                  val a' = f a
                in
                  go ls (D.insert dict l a')
                end

      in
        (list, go list dict)
      end

    fun remove lbl (list, dict) =
      (List.filter (fn l => not (L.eq (l, lbl))) list,
       D.remove dict lbl)

    fun splitList x =
      let
        fun go xs [] = (xs, [])
          | go xs (y :: ys) =
              if L.eq (y, x) then
                (xs, ys)
              else
                go (y :: xs) ys
      in
        go []
      end

    fun splice (list, dict) x (listx, dictx) =
      let
        val dict' = D.union (D.remove dict x) dictx (fn (l, _, _) => raise Fail ("splice: duplicates " ^ L.toString l))
        val (xs, ys) = splitList x list
      in
        (List.rev xs @ listx @ ys, dict')
      end

    fun truncateFrom (ys, dict) y =
      if D.member dict y then
        let
          val (xs, zs) = splitList y ys
        in
          (zs, List.foldl (fn (x, dict') => D.remove dict' x) dict xs)
        end
      else
        (ys, dict)

    fun dropUntil (ys, dict) y =
      if D.member dict y then
        let
          val (xs, zs) = splitList y ys
        in
          (xs, List.foldl (fn (z, dict') => D.remove dict' z) dict zs)
        end
      else
        (ys, dict)

    fun foldr alg z (list, dict) =
      List.foldl (fn (x, b) => alg (x, D.lookup dict x, b)) z list

    fun foldl alg z (list, dict) =
      List.foldr (fn (x, b) => alg (x, D.lookup dict x, b)) z list

    structure ConsView =
    struct
      type 'a telescope = 'a telescope
      type label = label

      datatype ('a, 'r) view =
          EMPTY
        | CONS of label * 'a * 'r

      val into =
        fn EMPTY => empty
         | CONS (lbl, a, r) => cons lbl a r

      val out =
        fn ([], _) => EMPTY
         | (xs as _ ::_, dict) =>
             let
               val x = List.last xs
               val a = D.lookup dict x
             in
               CONS (x, a, (List.take (xs, List.length xs - 1), D.remove dict x))
             end

      fun outAfter x t =
        out (dropUntil t x)
    end

    structure SnocView =
    struct
      type 'a telescope = 'a telescope
      type label = label

      datatype ('a, 'r) view =
           EMPTY
         | SNOC of 'r * label * 'a

      val out =
        fn ([], _) => EMPTY
         | (x :: xs, dict) => SNOC ((xs, D.remove dict x), x, D.lookup dict x)

      val into =
        fn EMPTY => empty
         | SNOC (r, x, a) => snoc r x a
    end
  end

  open Internal

  fun singleton lbl x =
    cons lbl x empty

  fun interposeAfter t x t' =
    splice t x (cons x (lookup t x) t')

  local
    open SnocView
  in
    fun subtelescope f (t1, t2) =
      let
        fun go EMPTY = true
          | go (SNOC (t1', lbl, a)) =
              case find t2 lbl of
                   NONE => false
                 | SOME a' => f (a, a') andalso go (out t1')
      in
        go (out t1)
      end

    fun eq f (t1, t2) =
      subtelescope f (t1, t2)
        andalso subtelescope f (t2, t1)
  end

end

functor TelescopeUtil (T : TELESCOPE) : TELESCOPE_UTIL =
struct
  open T

  fun search tel phi =
    let
      open SnocView
      val rec go =
        fn EMPTY => NONE
         | SNOC (tele', lbl, a) =>
             if phi a then
               SOME (lbl, a)
             else
               go (out tele')
    in
      go (out tel)
    end

  fun toString pretty =
    let
      open ConsView
      fun go r =
        fn EMPTY => r
         | CONS (lbl, a, tele') =>
            go (r ^ ", " ^ T.Label.toString lbl ^ " : " ^ pretty a) (out tele')
    in
      go "\194\183" o out
    end
end

functor TelescopeNotation (T : TELESCOPE) : TELESCOPE_NOTATION =
struct
  open T

  fun >: (tele, (l, a)) = snoc tele l a
end
