module dvdstarter_sui::whitelist {
    use std::vector;
    use std::hash;
    use sui::bcs;
    use suitears::merkle_proof;

    const ERROR_INVALID_PROOF: u64 = 0;

    public fun verify(
        root: vector<u8>,
        private_max_alloc: u64,
        public_max_alloc: u64,
        proof: vector<vector<u8>>,
        sender: address
    ) {        
        let payload = bcs::to_bytes(&sender);
        vector::append(&mut payload, bcs::to_bytes(&private_max_alloc));
        vector::append(&mut payload, bcs::to_bytes(&public_max_alloc));

        let leaf = hash::sha3_256(payload);
        assert!(merkle_proof::verify(&proof, root, leaf), ERROR_INVALID_PROOF);
    }
}