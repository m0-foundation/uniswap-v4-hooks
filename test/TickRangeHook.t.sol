// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { Currency } from "../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";

import { PoolSwapTest } from "../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { Ownable } from "../src/abstract/Ownable.sol";

import { IERC721Like } from "../src/interfaces/IERC721Like.sol";
import { IBaseTickRangeHook } from "../src/interfaces/IBaseTickRangeHook.sol";

import { TickRangeHook } from "../src/TickRangeHook.sol";

import { BaseTest } from "./utils/BaseTest.sol";

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

    /* ============ afterInitialize ============ */

    // TODO: move into integration test file
    function test_afterInitialize_moveTickInRange() public {
        // We initialize the pool at tick -1
        initPool(tickRangeHook, TickMath.getSqrtPriceAtTick(-1));

        (, int24 tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, -1);

        // Then deposit tokenZero single sided liquidity at tick 0
        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            TickMath.getSqrtPriceAtTick(0),
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            0
        );

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

    function test_afterInitialize_moveTickOutOfRange() public {
        // We initialize the pool at tick -1
        initPool(tickRangeHook, TickMath.getSqrtPriceAtTick(-1));

        (, int24 tick_, , ) = state.getSlot0(poolId);
        assertEq(tick_, -1);

        // Then deposit tokenZero single sided liquidity at tick 0
        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            TickMath.getSqrtPriceAtTick(0),
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            0
        );

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
}
