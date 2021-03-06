#!/bin/bash

#set -x # DEBUG

# encoding an SDF or a SMILES file is the same
# and it is the one we expect
diff <(./bin/molenc_type_atoms.py data/caff_coca.sdf) data/caff_coca_types.ref
diff <(./bin/molenc_type_atoms.py data/caff_coca.smi) data/caff_coca_types.ref

# ph4 features are the same than the ones extracted by ShowFeats.py
# (that were checked by hand and stored in a reference file)
diff <(./bin/molenc_ph4_type_atoms.py data/caff_coca.sdf) data/caff_coca_feats.ref

diff <(_build/default/src/pubchem_decoder.exe -i data/test_in.pbc -o /dev/stdout) data/test_out.ref

# atom pairs encoder tests
rm -f data/AP_test.smi.dix data/AP_test.txt # clean any previous run
molenc.sh --pairs -i data/AP_test.smi -o data/AP_test.txt
diff data/AP_test.smi.dix data/AP_test.smi.dix.ref
diff data/AP_test.txt data/AP_test.txt.ref
