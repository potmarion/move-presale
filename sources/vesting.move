module dvdstarter_sui::vesting {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};

    use suitears::math64;

    friend dvdstarter_sui::presale;

    struct VestingOwnerCap has key {
        id: UID
    }

    struct VestingState<phantom CoinReward> has key {
        id: UID,
        presale_id: ID,
        start_time: u64,
        total_amount: u64,
        initial_unlock: u64,
        release_interval: u64,
        release_rate: u64,
        lock_period: u64,
        vesting_period: u64,
        total_vested: u64,
        reward_balance: Balance<CoinReward>,
        unsold_token_withdraw: bool
    }

    struct Recipient<phantom CoinReward> has key {
        id: UID,
        vesting_id: ID,
        amount_vested: u64,
        amount_withdrawn: u64
    }

    const DECIMAL_PRECISION: u64 = 1000000;

    const ERROR_INVALID_RECIPIENT: u64 = 0;
    const ERROR_INVALID_AMOUNT: u64 = 1;
    const ERROR_EXCEED_TOTAL_AMOUNT: u64 = 2;
    const ERROR_INVALID_TIME: u64 = 3;
    const ERROR_ALREADY_WITHDRAWN: u64 = 4;

    fun init(ctx: &mut TxContext) {
        let owner_cap = VestingOwnerCap {
            id: object::new(ctx)
        };
        
        transfer::transfer(owner_cap, tx_context::sender(ctx));
    }

    entry fun transfer_ownercap(
        owner_cap: VestingOwnerCap,
        new_owner: address,
        _: &TxContext
    ) {
        transfer::transfer(owner_cap, new_owner);
    }

    entry fun create_vest<CoinReward>(
        _: &VestingOwnerCap,
        presale_id: ID,
        start_time: u64,
        initial_unlock: u64,
        release_interval: u64,
        release_rate: u64,
        lock_period: u64,
        vesting_period: u64,
        reward_fund: Coin<CoinReward>,
        ctx: &mut TxContext
    ) {
        let total_amount = coin::value(&reward_fund);
        let vesting_state = VestingState<CoinReward> {
            id: object::new(ctx),
            presale_id,
            start_time,
            total_amount,
            initial_unlock,
            release_interval,
            release_rate,
            lock_period,
            vesting_period,
            total_vested: 0,
            reward_balance: balance::zero(),
            unsold_token_withdraw: false
        };

        balance::join(&mut vesting_state.reward_balance, coin::into_balance(reward_fund));

        transfer::share_object(vesting_state);
    }

    entry fun set_start_time<CoinReward>(
        _: &VestingOwnerCap,
        vesting_state: &mut VestingState<CoinReward>,
        start_time: u64,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock);
        assert!(vesting_state.start_time == 0 || vesting_state.start_time >= timestamp, ERROR_INVALID_TIME);
        assert!(start_time > timestamp, ERROR_INVALID_TIME);

        vesting_state.start_time = start_time;
    }

    entry fun withdraw<CoinReward>(
        vesting_state: &mut VestingState<CoinReward>,
        recipient: &mut Recipient<CoinReward>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let vested = vested<CoinReward>(
            vesting_state,
            recipient,
            clock
        );
        let withdrawable = withdrawable<CoinReward>(
            vesting_state,
            recipient,
            clock
        );

        recipient.amount_withdrawn = vested;
        assert!(withdrawable > 0, ERROR_INVALID_AMOUNT);

        transfer::public_transfer(
            coin::take(&mut vesting_state.reward_balance, withdrawable, ctx),
            tx_context::sender(ctx)
        );
    }

    public(friend) fun create_user_recipient<CoinReward>(
        vesting_state: &VestingState<CoinReward>,
        ctx: &mut TxContext
    ) {
        let recipient = Recipient<CoinReward> {
            id: object::new(ctx),
            vesting_id: object::id(vesting_state),
            amount_vested: 0,
            amount_withdrawn: 0
        };

        transfer::transfer(recipient, tx_context::sender(ctx));
    }

    public(friend) fun update_recipient<CoinReward>(
        vesting_state: &mut VestingState<CoinReward>,
        recipient: &mut Recipient<CoinReward>,
        amount: u64,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock);
        assert!(vesting_state.start_time == 0 || vesting_state.start_time >= timestamp, ERROR_INVALID_TIME);

        assert!(object::id(vesting_state) == recipient.vesting_id, ERROR_INVALID_RECIPIENT);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);

        vesting_state.total_vested = vesting_state.total_vested + amount - recipient.amount_vested;
        assert!(vesting_state.total_amount >= vesting_state.total_vested, ERROR_EXCEED_TOTAL_AMOUNT);

        recipient.amount_vested = amount;
    }

    public(friend) fun withdraw_unsold<CoinReward>(
        vesting_state: &mut VestingState<CoinReward>,
        project_owner: address,
        ctx: &mut TxContext
    ) {
        assert!(vesting_state.unsold_token_withdraw == false, ERROR_ALREADY_WITHDRAWN);
        vesting_state.unsold_token_withdraw = true;

        let unsold_amount = vesting_state.total_amount - vesting_state.total_vested;
        transfer::public_transfer(
            coin::take(&mut vesting_state.reward_balance, unsold_amount, ctx),
            project_owner
        );
    }


    public fun presale_id<CoinReward>(
        vesting_state: &VestingState<CoinReward>
    ): ID {
        return vesting_state.presale_id
    }

    public fun vested<CoinReward>(
        vesting_state: &VestingState<CoinReward>,
        recipient: &Recipient<CoinReward>,
        clock: &Clock
    ) : u64 {
        let timestamp = clock::timestamp_ms(clock);
        let lock_end_time = vesting_state.start_time + vesting_state.lock_period;
        let vesting_end_time = lock_end_time + vesting_state.vesting_period;

        if (vesting_state.start_time == 0 || recipient.amount_vested == 0 || timestamp <= lock_end_time) {
            return 0
        };

        if (timestamp > vesting_end_time) {
            return recipient.amount_vested
        };

        let initial_unlock_amount = recipient.amount_vested * vesting_state.initial_unlock / DECIMAL_PRECISION;
        let unlock_amount_per_interval = recipient.amount_vested * vesting_state.release_rate / DECIMAL_PRECISION;
        let vested_amount = (timestamp - lock_end_time) / vesting_state.release_interval * unlock_amount_per_interval + initial_unlock_amount;
        vested_amount = math64::max(recipient.amount_withdrawn, vested_amount);

        return math64::min(vested_amount, recipient.amount_vested)  
    }

    public fun locked<CoinReward>(
        vesting_state: &VestingState<CoinReward>,
        recipient: &Recipient<CoinReward>,
        clock: &Clock
    ): u64 {
        return recipient.amount_vested - vested(vesting_state, recipient, clock)
    }

    public fun withdrawable<CoinReward>(
        vesting_state: &VestingState<CoinReward>,
        recipient: &Recipient<CoinReward>,
        clock: &Clock
    ): u64 {
        return vested(vesting_state, recipient, clock) - recipient.amount_withdrawn
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        init(ctx);
    }
}