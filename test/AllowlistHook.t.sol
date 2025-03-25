// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { Position } from "../lib/v4-periphery/lib/v4-core/src/libraries/Position.sol";
import { TickMath } from "../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { LiquidityAmounts } from "../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";
import { PoolSwapTest } from "../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { PositionConfig } from "../lib/v4-periphery/test/shared/PositionConfig.sol";

import { IPositionManager } from "../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { Ownable } from "../src/abstract/Ownable.sol";

import { IAllowlistHook } from "../src/interfaces/IAllowlistHook.sol";
import { IBaseActionsRouterLike } from "../src/interfaces/IBaseActionsRouterLike.sol";
import { IERC721Like } from "../src/interfaces/IERC721Like.sol";

import { AllowlistHook } from "../src/AllowlistHook.sol";

import { LiquidityOperationsLib } from "./utils/helpers/LiquidityOperationsLib.sol";
import { BaseTest } from "./utils/BaseTest.sol";

contract AllowlistHookTest is BaseTest {
    using LiquidityOperationsLib for IPositionManager;

    AllowlistHook public allowlistHook;

    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_FLAG);

    function setUp() public override {
        super.setUp();

        deployCodeTo(
            "AllowlistHook.sol",
            abi.encode(address(lpm), address(swapRouter), address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, owner),
            address(flags)
        );

        // Deploy WrappedMRewardsHook contract
        allowlistHook = AllowlistHook(address(flags));
        initPool(allowlistHook);

        IERC721Like(address(lpm)).setApprovalForAll(address(allowlistHook), true);
    }

    /* ============ beforeSwap ============ */

    function test_beforeSwap_swapperNotAllowed() public {
        vm.prank(owner);
        allowlistHook.setSwapRouterStatus(address(mockRouter), true);

        (, , bytes memory data_, uint256 value_) = _prepareSwapExactOutSingle(10_000e6, 10_000e6);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IAllowlistHook.SwapperNotAllowed.selector, alice)
        );

        _executeSwap(alice, data_, value_);
    }

    function test_beforeSwap_swapRouterNotTrusted() public {
        (, , bytes memory data_, uint256 value_) = _prepareSwapExactOutSingle(10_000e6, 10_000e6);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IAllowlistHook.SwapRouterNotTrusted.selector, address(mockRouter))
        );

        vm.prank(alice);
        mockRouter.executeActions{ value: value_ }(data_);
    }

    function test_beforeSwap() public {
        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatus(address(this), true);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        vm.prank(owner);
        allowlistHook.setSwapperStatus(address(this), true);

        vm.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(IBaseActionsRouterLike.msgSender.selector),
            abi.encode(address(this))
        );

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

    function test_beforeAddLiquidity_positionManagerNotAllowed() public {
        vm.prank(owner);
        allowlistHook.setPositionManagerStatus(address(lpm), false);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.PositionManagerNotTrusted.selector, address(lpm))
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e6, 1_000_000e6);
    }

    function test_beforeAddLiquidity_liquidityProviderNotAllowed() public {
        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.LiquidityProviderNotAllowed.selector, alice)
        );

        vm.prank(alice);
        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e6, 1_000_000e6);
    }

    function test_beforeAddLiquidity_reduceOnly() public {
        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatus(address(this), true);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        vm.prank(owner);
        allowlistHook.setPositionManagerStatus(address(lpm), false);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(address(lpm))),
            uint8(IAllowlistHook.PositionManagerStatus.REDUCE_ONLY)
        );

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.PositionManagerNotTrusted.selector, address(lpm))
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e6, 1_000_000e6);
    }

    function test_beforeAddLiquidity() public {
        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatus(address(this), true);

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

    /* ============ beforeRemoveLiquidity ============ */

    function test_beforeRemoveLiquidity_reduceOnly() public {
        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatus(address(this), true);

        uint256 tokenId_ = 1;
        bytes32 positionKey_ = Position.calculatePositionKey(
            address(lpm),
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            bytes32(tokenId_)
        );

        PositionConfig memory positionConfig_ = PositionConfig({
            poolKey: key,
            tickLower: TICK_LOWER_BOUND,
            tickUpper: TICK_UPPER_BOUND
        });

        uint128 positionLiquidity_ = LiquidityAmounts.getLiquidityForAmounts(
            SQRT_PRICE_0_0,
            TickMath.getSqrtPriceAtTick(TICK_LOWER_BOUND),
            TickMath.getSqrtPriceAtTick(TICK_UPPER_BOUND),
            1_000_000e6,
            1_000_000e6
        );

        lpm.mint(positionConfig_, positionLiquidity_, address(this), "");

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        vm.prank(owner);
        allowlistHook.setPositionManagerStatus(address(lpm), false);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(address(lpm))),
            uint8(IAllowlistHook.PositionManagerStatus.REDUCE_ONLY)
        );

        // Liquidity Provider should still be able to remove liquidity.
        lpm.decreaseLiquidity(tokenId_, positionConfig_, positionLiquidity_, "");

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.PositionManagerNotTrusted.selector, address(lpm))
        );

        // But should not be able to add liquidity anymore via this Position Manager.
        lpm.mint(positionConfig_, positionLiquidity_, address(this), "");
    }

    /* ============ setLiquidityProviderStatus ============ */

    function test_setLiquidityProviderStatus_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setLiquidityProviderStatus(alice, true);
    }

    function test_setLiquidityProviderStatus_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroLiquidityProvider.selector));

        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatus(address(0), true);
    }

    function test_setLiquidityProviderStatus() public {
        vm.expectEmit();
        emit IAllowlistHook.LiquidityProviderSet(alice, true);

        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatus(alice, true);

        assertTrue(allowlistHook.isLiquidityProviderAllowed(alice));
    }

    /* ============ setLiquidityProviderStatuses ============ */

    function test_setLiquidityProviderStatuses_onlyOwner() public {
        address[] memory liquidityProviders_ = new address[](3);
        liquidityProviders_[0] = alice;
        liquidityProviders_[1] = bob;
        liquidityProviders_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setLiquidityProviderStatuses(liquidityProviders_, statuses_);
    }

    function test_setLiquidityProviderStatuses_arrayLengthMismatch() public {
        address[] memory liquidityProviders_ = new address[](3);
        liquidityProviders_[0] = alice;
        liquidityProviders_[1] = bob;
        liquidityProviders_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatuses(liquidityProviders_, statuses_);
    }

    function test_setLiquidityProviderStatuses() public {
        address[] memory liquidityProviders_ = new address[](3);
        liquidityProviders_[0] = alice;
        liquidityProviders_[1] = bob;
        liquidityProviders_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(owner);
        allowlistHook.setLiquidityProviderStatuses(liquidityProviders_, statuses_);

        assertTrue(allowlistHook.isLiquidityProviderAllowed(alice));
        assertFalse(allowlistHook.isLiquidityProviderAllowed(bob));
        assertTrue(allowlistHook.isLiquidityProviderAllowed(carol));
    }

    /* ============ setSwapperStatus ============ */

    function test_setSwapperStatus_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setSwapperStatus(alice, true);
    }

    function test_setSwapperStatus_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapper.selector));

        vm.prank(owner);
        allowlistHook.setSwapperStatus(address(0), true);
    }

    function test_setSwapperStatus() public {
        vm.expectEmit();
        emit IAllowlistHook.SwapperSet(alice, true);

        vm.prank(owner);
        allowlistHook.setSwapperStatus(alice, true);

        assertTrue(allowlistHook.isSwapperAllowed(alice));
    }

    /* ============ setSwapperStatuses ============ */

    function test_setSwapperStatuses_onlyOwner() public {
        address[] memory swappers_ = new address[](3);
        swappers_[0] = alice;
        swappers_[1] = bob;
        swappers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setSwapperStatuses(swappers_, statuses_);
    }

    function test_setSwapperStatuses_arrayLengthMismatch() public {
        address[] memory swappers_ = new address[](3);
        swappers_[0] = alice;
        swappers_[1] = bob;
        swappers_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(owner);
        allowlistHook.setSwapperStatuses(swappers_, statuses_);
    }

    function test_setSwapperStatuses() public {
        address[] memory swappers_ = new address[](3);
        swappers_[0] = alice;
        swappers_[1] = bob;
        swappers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(owner);
        allowlistHook.setSwapperStatuses(swappers_, statuses_);

        assertTrue(allowlistHook.isSwapperAllowed(alice));
        assertFalse(allowlistHook.isSwapperAllowed(bob));
        assertTrue(allowlistHook.isSwapperAllowed(carol));
    }

    /* ============ setPositionManagerStatus ============ */

    function test_setPositionManagerStatus_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setPositionManagerStatus(mockPositionManager, true);
    }

    function test_setPositionManagerStatus_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroPositionManager.selector));

        vm.prank(owner);
        allowlistHook.setPositionManagerStatus(address(0), true);
    }

    function test_setPositionManagerStatus() public {
        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.FORBIDDEN)
        );

        vm.expectEmit();
        emit IAllowlistHook.PositionManagerSet(mockPositionManager, true);

        vm.prank(owner);
        allowlistHook.setPositionManagerStatus(mockPositionManager, true);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );

        vm.prank(owner);
        allowlistHook.setPositionManagerStatus(mockPositionManager, false);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.REDUCE_ONLY)
        );
    }

    /* ============ setPositionManagerStatuses ============ */

    function test_setPositionManagerStatuses_onlyOwner() public {
        address[] memory positionManagers_ = new address[](3);
        positionManagers_[0] = alice;
        positionManagers_[1] = bob;
        positionManagers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setPositionManagerStatuses(positionManagers_, statuses_);
    }

    function test_setPositionManagerStatuses_arrayLengthMismatch() public {
        address[] memory positionManagers_ = new address[](3);
        positionManagers_[0] = alice;
        positionManagers_[1] = bob;
        positionManagers_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(owner);
        allowlistHook.setPositionManagerStatuses(positionManagers_, statuses_);
    }

    function test_setPositionManagerStatuses() public {
        address[] memory positionManagers_ = new address[](3);
        positionManagers_[0] = alice;
        positionManagers_[1] = bob;
        positionManagers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(owner);
        allowlistHook.setPositionManagerStatuses(positionManagers_, statuses_);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(alice)),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(bob)),
            uint8(IAllowlistHook.PositionManagerStatus.FORBIDDEN)
        );

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(carol)),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );
    }

    /* ============ setSwapRouterStatus ============ */

    function test_setSwapRouterStatus_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setSwapRouterStatus(address(mockRouter), true);
    }

    function test_setSwapRouterStatus_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapRouter.selector));

        vm.prank(owner);
        allowlistHook.setSwapRouterStatus(address(0), true);
    }

    function test_setSwapRouterStatus() public {
        assertFalse(allowlistHook.isSwapRouterTrusted(address(mockRouter)));

        vm.expectEmit();
        emit IAllowlistHook.SwapRouterSet(address(mockRouter), true);

        vm.prank(owner);
        allowlistHook.setSwapRouterStatus(address(mockRouter), true);

        assertTrue(allowlistHook.isSwapRouterTrusted(address(mockRouter)));
    }

    /* ============ setSwapRouterStatuses ============ */

    function test_setSwapRouterStatuses_onlyOwner() public {
        address[] memory swapRouters_ = new address[](3);
        swapRouters_[0] = alice;
        swapRouters_[1] = bob;
        swapRouters_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setSwapRouterStatuses(swapRouters_, statuses_);
    }

    function test_setSwapRouterStatuses_arrayLengthMismatch() public {
        address[] memory swapRouters_ = new address[](3);
        swapRouters_[0] = alice;
        swapRouters_[1] = bob;
        swapRouters_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(owner);
        allowlistHook.setSwapRouterStatuses(swapRouters_, statuses_);
    }

    function test_setSwapRouterStatuses() public {
        address[] memory swapRouters_ = new address[](3);
        swapRouters_[0] = alice;
        swapRouters_[1] = bob;
        swapRouters_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(owner);
        allowlistHook.setSwapRouterStatuses(swapRouters_, statuses_);

        assertTrue(allowlistHook.isSwapRouterTrusted(alice));
        assertFalse(allowlistHook.isSwapRouterTrusted(bob));
        assertTrue(allowlistHook.isSwapRouterTrusted(carol));
    }
}
