// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";

import { PoolSwapTest } from "../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { Ownable } from "../src/abstract/Ownable.sol";

import { IAllowlistHook } from "../src/interfaces/IAllowlistHook.sol";
import { IBaseActionsRouterLike } from "../src/interfaces/IBaseActionsRouterLike.sol";
import { IERC721Like } from "../src/interfaces/IERC721Like.sol";

import { AllowlistHook } from "../src/AllowlistHook.sol";

import { BaseTest } from "./utils/BaseTest.sol";

contract AllowlistHookTest is BaseTest {
    AllowlistHook public allowlistHook;

    uint160 public flags =
        uint160(
            Hooks.AFTER_INITIALIZE_FLAG |
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                Hooks.AFTER_SWAP_FLAG |
                Hooks.BEFORE_SWAP_FLAG
        );

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
        allowlistHook.setSwapRouter(address(mockRouter));

        (, , bytes memory data_, uint256 value_) = _prepareSwapExactOutSingle(10_000e6, 10_000e6);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IAllowlistHook.SwapperNotAllowed.selector, alice)
        );

        _executeSwap(alice, data_, value_);
    }

    function test_beforeSwap_swapRouterNotAllowed() public {
        (, , bytes memory data_, uint256 value_) = _prepareSwapExactOutSingle(10_000e6, 10_000e6);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IAllowlistHook.SwapRouterNotAllowed.selector, address(mockRouter))
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
        allowlistHook.setPositionManager(mockPositionManager);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.PositionManagerNotAllowed.selector, address(lpm))
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
        emit IAllowlistHook.LiquidityProviderStatusSet(alice, true);

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
        emit IAllowlistHook.SwapperStatusSet(alice, true);

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

    /* ============ setPositionManager ============ */

    function test_setPositionManager_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setPositionManager(mockPositionManager);
    }

    function test_setPositionManager_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroPositionManager.selector));

        vm.prank(owner);
        allowlistHook.setPositionManager(address(0));
    }

    function test_setPositionManager() public {
        assertEq(allowlistHook.positionManager(), address(lpm));

        vm.expectEmit();
        emit IAllowlistHook.PositionManagerSet(mockPositionManager);

        vm.prank(owner);
        allowlistHook.setPositionManager(mockPositionManager);

        assertEq(allowlistHook.positionManager(), mockPositionManager);
    }

    /* ============ setSwapRouter ============ */

    function test_setSwapRouter_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        allowlistHook.setSwapRouter(address(mockRouter));
    }

    function test_setSwapRouter_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapRouter.selector));

        vm.prank(owner);
        allowlistHook.setSwapRouter(address(0));
    }

    function test_setSwapRouter() public {
        assertEq(allowlistHook.swapRouter(), address(swapRouter));

        vm.expectEmit();
        emit IAllowlistHook.SwapRouterSet(address(mockRouter));

        vm.prank(owner);
        allowlistHook.setSwapRouter(address(mockRouter));

        assertEq(allowlistHook.swapRouter(), address(mockRouter));
    }
}
