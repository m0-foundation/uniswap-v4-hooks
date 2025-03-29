// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { PoolSwapTest } from "../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { Proxy } from "../lib/common/src/Proxy.sol";

import { Ownable } from "../src/abstract/Ownable.sol";

import { IAdminMigratable } from "../src/interfaces/IAdminMigratable.sol";
import { IBaseTickRangeHook } from "../src/interfaces/IBaseTickRangeHook.sol";
import { IERC721Like } from "../src/interfaces/IERC721Like.sol";

import { TickRangeHook } from "../src/TickRangeHook.sol";

import { BaseTest, Foo, Migrator } from "./utils/BaseTest.sol";

contract TickRangeHookTest is BaseTest {
    TickRangeHook public tickRangeHook;

    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

    function setUp() public override {
        super.setUp();

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, owner),
            address(flags)
        );

        tickRangeHook = TickRangeHook(address(flags));

        IERC721Like(address(lpm)).setApprovalForAll(address(tickRangeHook), true);
    }

    /* ============ constructor ============ */

    function test_constructor_ticksOutOfOrder_lowerGTUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_LOWER_BOUND)
        );

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_UPPER_BOUND, TICK_LOWER_BOUND, owner),
            address(flags)
        );
    }

    function test_constructor_ticksOutOfOrder_lowerEqualUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_UPPER_BOUND)
        );

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_UPPER_BOUND, TICK_UPPER_BOUND, owner),
            address(flags)
        );
    }

    /* ============ afterSwap ============ */

    function test_afterSwap_invalidTick_outsideLowerBound() public {
        initPool(tickRangeHook);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        int24 tick_ = -1;

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, TICK_LOWER_BOUND, TICK_UPPER_BOUND)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1e6, // Exact output for input
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_afterSwap_invalidTick_outsideUpperBound() public {
        initPool(tickRangeHook);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        int24 tick_ = 2;

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, TICK_LOWER_BOUND, TICK_UPPER_BOUND)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 10_000_000e6, // Exact input for output
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_afterSwap_invalidTick_equalUpperBound() public {
        initPool(tickRangeHook);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        int24 tick_ = 1;

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, TICK_LOWER_BOUND, TICK_UPPER_BOUND)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 10_000_000e6, // Exact input for output
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_afterSwap() public {
        initPool(tickRangeHook);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 10_000e6, // Exact input for output swap
                sqrtPriceLimitX96: SQRT_PRICE_0_0 + 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        assertEq(sqrtPriceX96_, SQRT_PRICE_0_0 + 1);
        assertEq(tick_, 0);
    }

    /* ============ beforeAddLiquidity ============ */

    function test_beforeAddLiquidity_invalidTickRange_outsideLowerBound() public {
        initPool(tickRangeHook);

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                IBaseTickRangeHook.InvalidTickRange.selector,
                TICK_LOWER_BOUND - 1,
                TICK_UPPER_BOUND,
                TICK_LOWER_BOUND,
                TICK_UPPER_BOUND
            )
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e6, 1_000_000e6);
    }

    function test_beforeAddLiquidity_invalidTickRange_outsideUpperBound() public {
        initPool(tickRangeHook);

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                IBaseTickRangeHook.InvalidTickRange.selector,
                TICK_LOWER_BOUND,
                TICK_UPPER_BOUND + 1,
                TICK_LOWER_BOUND,
                TICK_UPPER_BOUND
            )
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND, TICK_UPPER_BOUND + 1, 1_000_000e6, 1_000_000e6);
    }

    function test_beforeAddLiquidity() public {
        initPool(tickRangeHook);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        assertEq(sqrtPriceX96_, SQRT_PRICE_0_0);
        assertEq(tick_, 0);
    }

    /* ============ setTickRange ============ */

    function test_setTickRange_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        tickRangeHook.setTickRange(1, 2);
    }

    function test_setTickRange_ticksOutOfOrder_lowerGTUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_LOWER_BOUND)
        );

        vm.prank(owner);
        tickRangeHook.setTickRange(TICK_UPPER_BOUND, TICK_LOWER_BOUND);
    }

    function test_setTickRange_ticksOutOfOrder_lowerEqualUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_UPPER_BOUND)
        );

        vm.prank(owner);
        tickRangeHook.setTickRange(TICK_UPPER_BOUND, TICK_UPPER_BOUND);
    }

    function test_setTickRange() public {
        vm.expectEmit();
        emit IBaseTickRangeHook.TickRangeSet(1, 2);

        vm.prank(owner);
        tickRangeHook.setTickRange(1, 2);
    }

    /* ============ migrate ============ */

    function test_migrate_onlyAdmin() external {
        address tickRangeHookProxy_ = address(new Proxy(address(tickRangeHook)));
        address migrator_ = address(new Migrator(address(new Foo())));

        vm.expectRevert(abi.encodeWithSelector(IAdminMigratable.UnauthorizedMigration.selector));
        IAdminMigratable(tickRangeHookProxy_).migrate(migrator_);
    }

    function test_migrate() external {
        address tickRangeHookProxy_ = address(new Proxy(address(tickRangeHook)));
        address migrator_ = address(new Migrator(address(new Foo())));

        vm.expectRevert();
        Foo(tickRangeHookProxy_).bar();

        vm.prank(owner);
        IAdminMigratable(tickRangeHookProxy_).migrate(migrator_);

        assertEq(Foo(tickRangeHookProxy_).bar(), 1);
    }
}
