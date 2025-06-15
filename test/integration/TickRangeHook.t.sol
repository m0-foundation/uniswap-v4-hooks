// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { PoolSwapTest } from "../../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { IERC721Like } from "../../src/interfaces/IERC721Like.sol";
import { IBaseTickRangeHook } from "../../src/interfaces/IBaseTickRangeHook.sol";

import { TickRangeHook } from "../../src/TickRangeHook.sol";

import { BaseTest } from "../utils/BaseTest.sol";

contract TickRangeHookIntegrationTest is BaseTest {
    TickRangeHook public tickRangeHook;

    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

    function setUp() public override {
        super.setUp();

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, hookManager),
            address(flags)
        );

        tickRangeHook = TickRangeHook(address(flags));

        IERC721Like(address(lpm)).setApprovalForAll(address(tickRangeHook), true);
    }

    /* ============ initialize ============ */

    function test_initialize_moveTickInRange() public {
        // We initialize the pool at tick -1
        initPool(tickRangeHook, TickMath.getSqrtPriceAtTick(-1));

        (, int24 tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, -1);

        // Then deposit tokenZero single sided liquidity at tick 0
        mintNewPosition(TickMath.getSqrtPriceAtTick(0), TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e6, 0);

        uint256 tokenZeroBalanceBeforeSwap_ = tokenZero.balanceOf(address(this));
        uint256 tokenOneBalanceBeforeSwap_ = tokenOne.balanceOf(address(this));

        // Then swap to move tick to tick 0
        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 500_000e6,
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(1)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        uint256 tokenZeroBalanceAfterSwap_ = tokenZero.balanceOf(address(this));
        uint256 tokenOneBalanceAfterSwap_ = tokenOne.balanceOf(address(this));
        (, tick_, , ) = state.getSlot0(poolId);

        // Should receive 500_000 tokenZero in exchange of...
        assertEq(tokenZeroBalanceAfterSwap_ - tokenZeroBalanceBeforeSwap_, 500_000e6);

        // 500_062.505627 tokenOne, which accounts for the 0.01% swap fee and 12.505627 of slippage
        assertEq(tokenOneBalanceBeforeSwap_ - tokenOneBalanceAfterSwap_, 500062505627);

        // Current tick is now 0
        assertEq(tick_, 0);
    }

    function test_initialize_moveTickOutOfRange() public {
        // We initialize the pool at tick -1
        initPool(tickRangeHook, TickMath.getSqrtPriceAtTick(-1));

        (, int24 tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, -1);

        // Then deposit tokenZero single sided liquidity at tick 0
        mintNewPosition(TickMath.getSqrtPriceAtTick(0), TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e6, 0);

        tick_ = 2;

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, TICK_LOWER_BOUND, TICK_UPPER_BOUND)
        );

        // Then swap to move tick out of range
        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 1_000_000e6,
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    /* ============ afterSwap ============ */

    function test_afterSwap_moveTickCloserToRange() public {
        int24 tickLowerBound_ = 0;
        int24 tickUpperBound_ = 10;

        vm.prank(hookManager);
        tickRangeHook.setTickRange(tickLowerBound_, tickUpperBound_);

        // We initialize the pool at tick 5
        initPool(tickRangeHook, SQRT_PRICE_5_0);

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        assertEq(sqrtPriceX96_, SQRT_PRICE_5_0);
        assertEq(tick_, 5);

        // Then provide liquidity between tick 0 and tick 10
        mintNewPosition(SQRT_PRICE_5_0, tickLowerBound_, tickUpperBound_, 1_000_000e6, 1_000_000e6);

        // Update the tick range
        tickLowerBound_ = 5;
        tickUpperBound_ = 20;

        vm.prank(hookManager);
        tickRangeHook.setTickRange(tickLowerBound_, tickUpperBound_);

        // Then provide liquidity between tick 5 and tick 20
        mintNewPosition(SQRT_PRICE_5_0, tickLowerBound_, tickUpperBound_, 1_000_000e6, 1_000_000e6);

        // Update the tick range
        tickLowerBound_ = 20;
        tickUpperBound_ = 30;

        vm.prank(hookManager);
        tickRangeHook.setTickRange(tickLowerBound_, tickUpperBound_);

        (, tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, 5);

        // Should revert since tick is moving further below the range
        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, 2, tickLowerBound_, tickUpperBound_)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 500_000e6,
                sqrtPriceLimitX96: SQRT_PRICE_0_0
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        (, tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, 5);

        tick_ = 31;

        // Should revert since tick is moving further above the range
        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, tickLowerBound_, tickUpperBound_)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 2_000_000e6,
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        tick_ = 19;

        // Should succeed since tick is moving closer to the range
        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 2_000_000e6,
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        (, tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, 19);

        tick_ = 25;

        // Should succeed to bring tick in range
        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 2_000_000e6,
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        (, tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, 25);
    }
}
