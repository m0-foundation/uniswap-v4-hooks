// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { PoolSwapTest } from "../../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { IERC721Like } from "../../src/interfaces/IERC721Like.sol";

import { TickRangeHook } from "../../src/TickRangeHook.sol";

import { BaseTest } from "../utils/BaseTest.sol";

contract TickRangeHookIntegrationTest is BaseTest {
    TickRangeHook public tickRangeHook;

    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG);

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

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);
        assertEq(sqrtPriceX96_, TickMath.getSqrtPriceAtTick(-1));
        assertEq(tick_, -1);

        // Then deposit tokenZero single sided liquidity at tick 0
        mintNewPosition(TickMath.getSqrtPriceAtTick(0), TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e6, 0);

        uint160 sqrtPriceLimitX96_ = TickMath.getSqrtPriceAtTick(2);

        // Then swap to move tick out of range
        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 1_000_000e6,
                sqrtPriceLimitX96: sqrtPriceLimitX96_
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        (sqrtPriceX96_, tick_, , ) = state.getSlot0(poolId);
        assertEq(sqrtPriceX96_, sqrtPriceLimitX96_);
        assertEq(tick_, 2);
    }
}
