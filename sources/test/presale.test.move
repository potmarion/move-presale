#[test_only]
module dvdstarter_sui::presale_test {

    use sui::test_utils::assert_eq;
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::bcs;
    use std::debug;
    use std::vector;
    use std::hash;

    use dvdstarter_sui::presale::{Self, PresaleOwnerCap, PresaleState, Recipient as PresaleRecipient};
    use dvdstarter_sui::vesting;
    use dvdstarter_sui::fund::{Self, FUND};
    use dvdstarter_sui::reward::{Self, REWARD};
    use dvdstarter_sui::test_utils::{scenario, people};
       
    use dvdstarter_sui::whitelist;


    const DECIMAL_PRECISION: u64 = 1000000;

    const ERROR_INVALID_PROOF: u64 = 0;


    #[test]
    fun test_create_sale() {
        // let private_max_alloc = 100;
        // let public_max_alloc = 200;
        // let kyc_passed = true;
        // let payload = bcs::to_bytes(&private_max_alloc);
        // vector::append(&mut payload, bcs::to_bytes(&public_max_alloc));
        // vector::append(&mut payload, bcs::to_bytes(&kyc_passed));

        let alice = @0x0bf4e8d5c406fd2c759b7f937b8a016d267e7afeb94f1111faab21e950dbd759;
        let amount1 = 1000000000;
        let amount2 = 1000000000;
        let payload = bcs::to_bytes(&alice);
        vector::append(&mut payload, bcs::to_bytes(&amount1));
        vector::append(&mut payload, bcs::to_bytes(&amount2));
        let leaf = hash::sha3_256(payload);
        debug::print(&leaf);

        let root = x"9d600837d4e748bb803fd2f2a441ca7e4b64fb628e1ce34fd0b175038918165f";
        let leaf = x"2fa5146f23de070154f87ee3b0a12bcfa60192b5640fcdf8badc401df9c10227";
        let proof = vector[
            x"deb19eb63fe1ac01e28eb6bca2a83235908d9deba5c51aa8a20a54715ee73ccb",
            x"072bf5403e74283b4bc52bd73bf4a4b8ba17d79b4e365f926da5fa8254186167",
            x"f4559afd8e2ff58ff025aae950969f2f748bcf78b06ba56bf5be1a9013876d94"
        ];
        assert_eq(whitelist::verify(root, amount1, amount2, proof, alice), true);
        // let scenario = scenario();
        // setup_senario(&mut scenario);

        // test::end(scenario);
    }

    // fun setup_senario(scenario: &mut Scenario) {
    //     let (owner, _) = people();

    //     next_tx(scenario, owner);
    //     {
    //         fund::init_for_test(ctx(scenario));
    //     };

    //     next_tx(scenario, owner);
    //     {
    //         reward::init_for_test(ctx(scenario));
    //     };
    
    //     next_tx(scenario, owner);
    //     {
    //         let c = clock::create_for_testing(ctx(scenario));
    //         let timestamp = clock::timestamp_ms(&c);

    //         presale::init_for_test(ctx(scenario));
    //         let owner_cap = test::take_from_sender<PresaleOwnerCap>(scenario);
    //         presale::create_sale<FUND, REWARD>(
    //             &owner_cap,
    //             x"d5852c8cb4936ab82010fafae6015d1975349c15ae06acb79c1cf95bbbbd4e23",
    //             DECIMAL_PRECISION,
    //             timestamp + 1000000,
    //             1000000,
    //             1000000,
    //             DECIMAL_PRECISION / 100,
    //             6,
    //             6,
    //             1000000000000,
    //             ctx(scenario)
    //         );

    //         clock::destroy_for_testing(c);
    //         test::return_to_sender<PresaleOwnerCap>(scenario, owner_cap);
    //     };

    //     next_tx(scenario, owner);
    //     {
    //         vesting::init_for_test(ctx(scenario));
    //     };
    // }
}
// d5852c8cb4936ab82010fafae6015d1975349c15ae06acb79c1cf95bbbbd4e23