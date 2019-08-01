
(* Weighted Minwise Hashing in Constant Time

   Shrivastava, A. (2016).
   Simple and efficient weighted minwise hashing.
   In Advances in Neural Information Processing Systems (pp. 1498-1506). *)

module A = Array
module BA = Bigarray
module BA1 = BA.Array1
module Fp = Fingerprint

type dense = (int, BA.int8_unsigned_elt, BA.c_layout) BA1.t

type hashed = dense (* but the array will be shorter *)

(* any feature value [x] must satisfy [x < feat_val_bound] *)
let feat_val_bound = 256
let k = 50 (* number of hashes we want *)

let seeds =
  let global_seed = 12345 in
  let rng = Random.State.make [|global_seed|] in
  let bound = (BatInt.pow 2 30) - 1 in
  Array.init k (fun _ -> Random.State.int rng bound)

(* convert the sparse Fp.t type into a dense array of small positive ints *)
let to_dense feat_id_bound fp =
  let res = BA1.create BA.int8_unsigned BA.C_layout feat_id_bound in
  BA1.fill res 0;
  let n = BA1.dim fp in
  let i = ref 0 in
  while !i < n do
    (* unsafe *)
    let k = BA1.unsafe_get fp !i in
    let v = BA1.unsafe_get fp (!i + 1) in
    assert(k < feat_id_bound && v < feat_val_bound);
    BA1.unsafe_set res k v;
    i := !i + 2
  done;
  res

let is_red a test_feat_id test_feat_val =
  let feat_val = BA1.unsafe_get a test_feat_id in
  (feat_val = 0) || (test_feat_val > feat_val)

(* compute k hashes *)
let hash dense_fp =
  let feat_id_bound = BA1.dim dense_fp in
  let res = BA1.create BA.int8_unsigned BA.C_layout k in
  BA1.fill res 0;
  for i = 0 to k - 1 do
    let seed = A.unsafe_get seeds i in
    let rng = Random.State.make [|seed|] in
    (* FBR: we could use a single rand then modulo,
            if performance in here really matters *)
    let test_feat_id = ref (Random.State.int rng feat_id_bound) in
    let test_feat_val = ref (Random.State.int rng feat_val_bound) in
    while is_red dense_fp !test_feat_id !test_feat_val do
      BA1.unsafe_set res i (1 + BA1.unsafe_get res i); (* Hashes[i]++ *)
      test_feat_id := Random.State.int rng feat_id_bound;
      test_feat_val := Random.State.int rng feat_val_bound
    done
  done;
  res

let estimate_jaccard hash1 hash2 =
  let res = ref 0 in
  for i = 0 to k - 1 do
    if (BA1.unsafe_get hash1 i) = (BA1.unsafe_get hash2 i) then
      incr res
  done;
  (float !res) /. (float k)

let estimate_distance h1 h2 =
  1.0 -. (estimate_jaccard h1 h2)
