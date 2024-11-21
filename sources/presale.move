module dvdstarter_sui::presale {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::transfer;
    // use sui::event;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};

    use dvdstarter_sui::whitelist;
    use dvdstarter_sui::vesting::{Self, VestingState, Recipient as VestingRecipient};

    const DECIMAL_PRECISION: u64 = 1000000;

    const ERROR_PRESALE_STARTED: u64 = 0;
    const ERROR_PAST_TIME: u64 = 1;
    const ERROR_PRIVATE_NOT_OVER: u64 = 2;
    const ERROR_PRESALE_NOT_PAUSED: u64 = 3;
    // const ERROR_KYC_NOT_PASSED: u64 = 4;
    const ERROR_NOT_IN_CLOSE_PERIOD: u64 = 5;
    const ERROR_EXCEED_PUBLIC_ALLOC: u64 = 6;
    const ERROR_PRIVATE_OVER: u64 = 7;
    // const ERROR_NOT_ALLOWED_PRIVATE: u64 = 8;
    const ERROR_EXCEED_PRIVATE_ALLOC: u64 = 9;
    const ERROR_PRESALE_PAUSED: u64 = 10;
    const ERROR_PRESALE_NOT_GOING: u64 = 11;
    const ERROR_PRESALE_NOT_ENDED: u64 = 12;
    const ERROR_INVALID_RECIPIENT: u64 = 13;
    const ERROR_INVALID_VESTING: u64 = 14;


    struct PresaleOwnerCap has key {
        id: UID
    }

    struct PresaleState<phantom CoinFund, phantom CoinReward> has key {
        id: UID,
        root: vector<u8>,
        exchange_rate: u64,
        private_start_time: u64,
        start_time: u64,
        period: u64,
        close_period: u64,
        service_fee: u64,
        current_presale_period: u64,
        private_sold_amount: u64,
        public_sold_amount: u64,
        fund_balance: Balance<CoinFund>,
        is_private_sale_over: bool,
        is_presale_paused: bool,
        fund_coin_decimal: u64,
        reward_coin_decimal: u64,
        initial_rewards_amount: u64
    }

    struct Recipient<phantom CoinFund, phantom CoinReward> has key {
        id: UID,
        presale_id: ID,
        private_ft_balance: u64,
        ft_balance: u64,
        rt_balance: u64,
    }

    fun init(ctx: &mut TxContext) {
        let owner_cap = PresaleOwnerCap {
            id: object::new(ctx)
        };
        
        transfer::transfer(owner_cap, tx_context::sender(ctx));
    }

    entry fun transfer_ownercap(
        owner_cap: PresaleOwnerCap,
        new_owner: address,
        _: &TxContext
    ) {
        transfer::transfer(owner_cap, new_owner);
    }

    entry fun create_sale<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        root: vector<u8>,
        exchange_rate: u64,
        private_start_time: u64,
        start_time: u64,
        period: u64,
        close_period: u64,
        service_fee: u64,
        fund_coin_decimal: u64,
        reward_coin_decimal: u64,
        initial_rewards_amount: u64,
        ctx: &mut TxContext
    ) {
        let presale_state = PresaleState<CoinFund, CoinReward> {
            id: object::new(ctx),
            root,
            exchange_rate,
            private_start_time,
            start_time,
            period,
            close_period,
            service_fee,
            current_presale_period: period,
            private_sold_amount: 0,
            public_sold_amount: 0,
            fund_balance: balance::zero(),
            is_private_sale_over: false,
            is_presale_paused: false,
            fund_coin_decimal,
            reward_coin_decimal,
            initial_rewards_amount
        };

        transfer::share_object(presale_state);
    }

    entry fun create_user_recipient<CoinFund, CoinReward>(
        presale_state: &PresaleState<CoinFund, CoinReward>,
        vesting_state: &VestingState<CoinReward>,
        ctx: &mut TxContext
    ) {
        assert!(object::id(presale_state) == vesting::presale_id<CoinReward>(vesting_state), ERROR_INVALID_VESTING);

        let recipient = Recipient<CoinFund, CoinReward> {
            id: object::new(ctx),
            presale_id: object::id(presale_state),
            private_ft_balance: 0,
            ft_balance: 0,
            rt_balance: 0,
        };

        transfer::transfer(recipient, tx_context::sender(ctx));

        vesting::create_user_recipient<CoinReward>(
            vesting_state,
            ctx
        );
    }

    entry fun set_close_period<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        close_period: u64,
        _ctx: &mut TxContext
    ) {
        presale_state.close_period = close_period;
    }

    entry fun end_private_sale<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        presale_state.is_private_sale_over = true;
        let timestamp = clock::timestamp_ms(clock);

        if (presale_state.start_time < timestamp) {
            presale_state.start_time = timestamp
        };
    }

    entry fun set_start_time<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        start_time: u64,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock);
        assert!(presale_state.start_time >= timestamp, ERROR_PRESALE_STARTED);
        assert!(start_time > timestamp, ERROR_PAST_TIME);

        presale_state.start_time = start_time;
    }

    entry fun start_presale<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(presale_state.is_private_sale_over, ERROR_PRIVATE_NOT_OVER);

        let timestamp = clock::timestamp_ms(clock);
        assert!(presale_state.start_time > timestamp, ERROR_PRESALE_STARTED);
        
        presale_state.start_time = timestamp;
    }

    entry fun extend_period<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        extend_time: u64,
        _ctx: &mut TxContext
    ) {
        presale_state.period = presale_state.period + extend_time;
        presale_state.current_presale_period = presale_state.current_presale_period + extend_time;
    }

    entry fun pause_presale_by_emergency<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert_presale_going(presale_state, clock);

        presale_state.is_presale_paused = true;
        let timestamp = clock::timestamp_ms(clock);
        presale_state.current_presale_period = presale_state.start_time + presale_state.current_presale_period - timestamp;
    }

    entry fun resume_presale<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(presale_state.is_presale_paused, ERROR_PRESALE_NOT_PAUSED);
        presale_state.is_presale_paused = false;
        let timestamp = clock::timestamp_ms(clock);
        presale_state.start_time = timestamp;
    }

    entry fun deposit<CoinFund, CoinReward>(
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        user_recipient: &mut Recipient<CoinFund, CoinReward>,
        vesting_state: &mut VestingState<CoinReward>,
        vesting_recipient: &mut VestingRecipient<CoinReward>,
        private_max_alloc: u64,
        public_max_alloc: u64,
        proof: vector<vector<u8>>,
        user_fund: Coin<CoinFund>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert_presale_going(presale_state, clock);
        assert!(object::id(presale_state) == user_recipient.presale_id, ERROR_INVALID_RECIPIENT);
        assert!(object::id(presale_state) == vesting::presale_id<CoinReward>(vesting_state), ERROR_INVALID_VESTING);

        whitelist::verify(
            presale_state.root,
            private_max_alloc,
            public_max_alloc,
            proof,
            tx_context::sender(ctx)
        );

        let timestamp = clock::timestamp_ms(clock);
        if (private_max_alloc > 0) {
            let end_time = presale_state.start_time + presale_state.current_presale_period;
            assert!(timestamp >= (end_time - presale_state.close_period) && timestamp <= end_time, ERROR_NOT_IN_CLOSE_PERIOD);
        };

        let amount = coin::value(&user_fund);
        let new_ft_Balance = user_recipient.ft_balance + amount;
        assert!(public_max_alloc + user_recipient.private_ft_balance >= new_ft_Balance, ERROR_EXCEED_PUBLIC_ALLOC);

        let rt_amount = amount * DECIMAL_PRECISION / presale_state.exchange_rate
            * presale_state.reward_coin_decimal / presale_state.fund_coin_decimal;
        user_recipient.ft_balance = new_ft_Balance;
        user_recipient.rt_balance = user_recipient.rt_balance + rt_amount;
        presale_state.public_sold_amount = presale_state.public_sold_amount + amount;

        balance::join(&mut presale_state.fund_balance, coin::into_balance(user_fund));

        vesting::update_recipient<CoinReward>(
            vesting_state,
            vesting_recipient,
            user_recipient.rt_balance,
            clock,
            ctx
        );
    }

    entry fun deposit_private<CoinFund, CoinReward>(
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        user_recipient: &mut Recipient<CoinFund, CoinReward>,
        vesting_state: &mut VestingState<CoinReward>,
        vesting_recipient: &mut VestingRecipient<CoinReward>,
        private_max_alloc: u64,
        public_max_alloc: u64,
        proof: vector<vector<u8>>,
        user_fund: Coin<CoinFund>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!presale_state.is_private_sale_over, ERROR_PRIVATE_OVER);
        assert!(object::id(presale_state) == user_recipient.presale_id, ERROR_INVALID_RECIPIENT);
        assert!(object::id(presale_state) == vesting::presale_id<CoinReward>(vesting_state), ERROR_INVALID_VESTING);

        whitelist::verify(
            presale_state.root,
            private_max_alloc,
            public_max_alloc,
            proof,
            tx_context::sender(ctx)
        );

        let _timestamp = clock::timestamp_ms(clock);
        let amount = coin::value(&user_fund);
        let new_ft_Balance = user_recipient.ft_balance + amount;
        assert!(private_max_alloc >= new_ft_Balance, ERROR_EXCEED_PRIVATE_ALLOC);

        let rt_amount = amount * DECIMAL_PRECISION / presale_state.exchange_rate;
        user_recipient.ft_balance = new_ft_Balance;
        user_recipient.rt_balance = user_recipient.rt_balance + rt_amount;
        user_recipient.private_ft_balance = user_recipient.private_ft_balance + amount;
        presale_state.private_sold_amount = presale_state.private_sold_amount + amount;

        balance::join(&mut presale_state.fund_balance, coin::into_balance(user_fund));

        vesting::update_recipient<CoinReward>(
            vesting_state,
            vesting_recipient,
            user_recipient.rt_balance,
            clock,
            ctx
        );
    }

    entry fun withdraw_fund<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &mut PresaleState<CoinFund, CoinReward>,
        treasury: address,
        project_owner: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert_presale_finished(
            presale_state,
            clock
        );

        let total_ft_balance = balance::value(&presale_state.fund_balance);
        let fee_amount = total_ft_balance * presale_state.service_fee / DECIMAL_PRECISION;
        let actual_fund_amount = total_ft_balance - fee_amount;

        transfer::public_transfer(
            coin::take(&mut presale_state.fund_balance, fee_amount, ctx),
            treasury
        );

        transfer::public_transfer(
            coin::take(&mut presale_state.fund_balance, actual_fund_amount, ctx),
            project_owner
        );
    }

    entry fun withdraw_unsold<CoinFund, CoinReward>(
        _: &PresaleOwnerCap,
        presale_state: &PresaleState<CoinFund, CoinReward>,
        vesting_state: &mut VestingState<CoinReward>,
        project_owner: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert_presale_finished(presale_state, clock);
        assert!(object::id(presale_state) == vesting::presale_id<CoinReward>(vesting_state), ERROR_INVALID_VESTING);

        vesting::withdraw_unsold(vesting_state, project_owner, ctx);
    }

    public fun assert_presale_going<CoinFund, CoinReward>(
        presale_state: &PresaleState<CoinFund, CoinReward>,
        clock: &Clock
    ) {
        assert!(!presale_state.is_presale_paused, ERROR_PRESALE_PAUSED);
        let end_time = presale_state.start_time + presale_state.current_presale_period;
        let timestamp = clock::timestamp_ms(clock);
        assert!(timestamp >= presale_state.start_time && timestamp <= end_time, ERROR_PRESALE_NOT_GOING);
    }

    public fun assert_presale_finished<CoinFund, CoinReward>(
        presale_state: &PresaleState<CoinFund, CoinReward>,
        clock: &Clock
    ) {
        let timestamp = clock::timestamp_ms(clock);
        assert!(timestamp > presale_state.start_time + presale_state.current_presale_period, ERROR_PRESALE_NOT_ENDED);
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        init(ctx);
    }
}