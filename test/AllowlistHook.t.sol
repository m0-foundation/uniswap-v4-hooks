// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import { console } from "../lib/forge-std/src/console.sol";
import {
    IAccessControl
} from "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { LiquidityAmounts } from "../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";
import { PoolSwapTest } from "../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { PositionConfig } from "../lib/v4-periphery/test/shared/PositionConfig.sol";

import { IPositionManager } from "../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { IAllowlistHook } from "../src/interfaces/IAllowlistHook.sol";
import { IBaseActionsRouterLike } from "../src/interfaces/IBaseActionsRouterLike.sol";
import { IERC721Like } from "../src/interfaces/IERC721Like.sol";

import { AllowlistHook } from "../src/AllowlistHook.sol";

import { LiquidityOperationsLib } from "./utils/helpers/LiquidityOperationsLib.sol";
import { BaseTest } from "./utils/BaseTest.sol";
import { AllowlistHookUpgrade } from "./utils/Mocks.sol";

contract AllowlistHookTest is BaseTest {
    using LiquidityOperationsLib for IPositionManager;

    // Deploy the implementation contract
    AllowlistHook public allowlistHookImplementation = new AllowlistHook();
    AllowlistHook public allowlistHook;

    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_FLAG);

    function setUp() public override {
        super.setUp();

        // Deploy the proxy contract to the mined address
        bytes memory implementationInitializeCall = abi.encodeCall(
            AllowlistHook.initialize,
            (
                address(lpm),
                address(swapRouter),
                address(manager),
                TICK_LOWER_BOUND,
                TICK_UPPER_BOUND,
                admin,
                hookManager,
                upgrader
            )
        );

        bytes memory proxyConstructorArgs = abi.encode(allowlistHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 144)); // Namespace the hook to avoid collisions

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        allowlistHook = AllowlistHook(namespacedFlags);
        Hooks.validateHookPermissions(allowlistHook, allowlistHook.getHookPermissions());

        initPool(allowlistHook);

        IERC721Like(address(lpm)).setApprovalForAll(address(allowlistHook), true);
    }

    /* ============ beforeSwap ============ */

    function test_beforeSwap_swapperNotAllowed() public {
        vm.prank(hookManager);
        allowlistHook.setSwapRouter(address(mockRouter), true);

        (, , bytes memory data_, uint256 value_) = _prepareSwapExactOutSingle(10_000e18, 10_000e18);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IAllowlistHook.SwapperNotAllowed.selector, alice)
        );

        _executeSwap(alice, data_, value_);
    }

    function test_beforeSwap_swapRouterNotTrusted() public {
        (, , bytes memory data_, uint256 value_) = _prepareSwapExactOutSingle(10_000e18, 10_000e18);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IAllowlistHook.SwapRouterNotTrusted.selector, address(mockRouter))
        );

        vm.prank(alice);
        mockRouter.executeActions{ value: value_ }(data_);
    }

    function test_beforeSwap_zeroForOne_exactInput() public {
        int256 amountSpecified_ = 10_000e18;

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);

        vm.prank(hookManager);
        allowlistHook.setTickRange(-1, TICK_UPPER_BOUND);

        vm.prank(hookManager);
        allowlistHook.setSwapper(address(this), true);

        vm.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(IBaseActionsRouterLike.msgSender.selector),
            abi.encode(address(this))
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -amountSpecified_,
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(-1)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_beforeSwap_zeroForOne_exactOutput() public {
        int256 amountSpecified_ = 10_000e18;

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);

        vm.prank(hookManager);
        allowlistHook.setTickRange(-1, TICK_UPPER_BOUND);

        vm.prank(hookManager);
        allowlistHook.setSwapper(address(this), true);

        vm.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(IBaseActionsRouterLike.msgSender.selector),
            abi.encode(address(this))
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: amountSpecified_,
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(-1)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_beforeSwap_oneForZero_exactInput() public {
        int256 amountSpecified_ = 10_000e18;

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);

        vm.prank(hookManager);
        allowlistHook.setSwapper(address(this), true);

        vm.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(IBaseActionsRouterLike.msgSender.selector),
            abi.encode(address(this))
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: -amountSpecified_,
                sqrtPriceLimitX96: SQRT_PRICE_0_0 + 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_beforeSwap_oneForZero_exactOutput() public {
        int256 amountSpecified_ = 10_000e18;

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);

        vm.prank(hookManager);
        allowlistHook.setSwapper(address(this), true);

        vm.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(IBaseActionsRouterLike.msgSender.selector),
            abi.encode(address(this))
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: amountSpecified_,
                sqrtPriceLimitX96: SQRT_PRICE_0_0 + 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_beforeSwap() public {
        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e18,
            1_000_000e18
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        vm.prank(hookManager);
        allowlistHook.setSwapper(address(this), true);

        vm.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(IBaseActionsRouterLike.msgSender.selector),
            abi.encode(address(this))
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 10_000e18,
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
        vm.prank(hookManager);
        allowlistHook.setPositionManager(address(lpm), false);

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.PositionManagerNotTrusted.selector, address(lpm))
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);
    }

    function test_beforeAddLiquidity_liquidityProviderNotAllowed() public {
        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.LiquidityProviderNotAllowed.selector, alice)
        );

        vm.prank(alice);
        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);
    }

    function test_beforeAddLiquidity_reduceOnly() public {
        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);

        vm.prank(hookManager);
        allowlistHook.setPositionManager(address(lpm), false);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(address(lpm))),
            uint8(IAllowlistHook.PositionManagerStatus.REDUCE_ONLY)
        );

        expectWrappedRevert(
            address(allowlistHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(IAllowlistHook.PositionManagerNotTrusted.selector, address(lpm))
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e18, 1_000_000e18);
    }

    function test_beforeAddLiquidity() public {
        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e18,
            1_000_000e18
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        assertEq(sqrtPriceX96_, SQRT_PRICE_0_0);
        assertEq(tick_, 0);
    }

    /* ============ beforeRemoveLiquidity ============ */

    function test_beforeRemoveLiquidity_reduceOnly() public {
        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(this), true);

        uint256 tokenId_ = 1;

        PositionConfig memory positionConfig_ = PositionConfig({
            poolKey: key,
            tickLower: TICK_LOWER_BOUND,
            tickUpper: TICK_UPPER_BOUND
        });

        uint128 positionLiquidity_ = LiquidityAmounts.getLiquidityForAmounts(
            SQRT_PRICE_0_0,
            TickMath.getSqrtPriceAtTick(TICK_LOWER_BOUND),
            TickMath.getSqrtPriceAtTick(TICK_UPPER_BOUND),
            1_000_000e18,
            1_000_000e18
        );

        lpm.mint(positionConfig_, positionLiquidity_, address(this), "");

        vm.prank(hookManager);
        allowlistHook.setPositionManager(address(lpm), false);

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

    /* ============ setLiquidityProvidersAllowlist ============ */

    function test_setLiquidityProvidersAllowlist_onlyHookManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setLiquidityProvidersAllowlist(false);
    }

    function test_setLiquidityProvidersAllowlist_noChange() public {
        // Enabled by default at deployment
        assertTrue(allowlistHook.isLiquidityProvidersAllowlistEnabled());

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvidersAllowlist(true);

        assertTrue(allowlistHook.isLiquidityProvidersAllowlistEnabled());
    }

    function test_setLiquidityProvidersAllowlist() public {
        // Enabled by default at deployment
        assertTrue(allowlistHook.isLiquidityProvidersAllowlistEnabled());

        bool isEnabled_ = false;

        vm.expectEmit();
        emit IAllowlistHook.LiquidityProvidersAllowlistSet(isEnabled_);

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvidersAllowlist(isEnabled_);

        assertFalse(allowlistHook.isLiquidityProvidersAllowlistEnabled());
    }

    function testFuzz_setLiquidityProvidersAllowlist(bool isEnabled_, uint256 index_) public {
        address caller = _getUser(index_);

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            // Will return early if status is the same as the current one
            if (allowlistHook.isLiquidityProvidersAllowlistEnabled() != isEnabled_) {
                vm.expectEmit();
                emit IAllowlistHook.LiquidityProvidersAllowlistSet(isEnabled_);
            }
        }

        vm.prank(caller);
        allowlistHook.setLiquidityProvidersAllowlist(isEnabled_);

        if (caller != hookManager) return;

        assertEq(allowlistHook.isLiquidityProvidersAllowlistEnabled(), isEnabled_);
    }

    /* ============ setSwappersAllowlist ============ */

    function test_setSwappersAllowlist_onlyHookManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setSwappersAllowlist(true);
    }

    function test_setSwappersAllowlist_noChange() public {
        // Enabled by default at deployment
        assertTrue(allowlistHook.isSwappersAllowlistEnabled());

        vm.prank(hookManager);
        allowlistHook.setSwappersAllowlist(true);

        assertTrue(allowlistHook.isSwappersAllowlistEnabled());
    }

    function test_setSwappersAllowlist() public {
        // Enabled by default at deployment
        assertTrue(allowlistHook.isSwappersAllowlistEnabled());

        bool isEnabled_ = false;

        vm.expectEmit();
        emit IAllowlistHook.SwappersAllowlistSet(isEnabled_);

        vm.prank(hookManager);
        allowlistHook.setSwappersAllowlist(isEnabled_);

        assertFalse(allowlistHook.isSwappersAllowlistEnabled());
    }

    function testFuzz_setSwappersAllowlist(bool isEnabled_, uint256 index_) public {
        address caller = _getUser(index_);

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            // Will return early if status is the same as the current one
            if (allowlistHook.isSwappersAllowlistEnabled() != isEnabled_) {
                vm.expectEmit();
                emit IAllowlistHook.SwappersAllowlistSet(isEnabled_);
            }
        }

        vm.prank(caller);
        allowlistHook.setSwappersAllowlist(isEnabled_);

        if (caller != hookManager) return;

        assertEq(allowlistHook.isSwappersAllowlistEnabled(), isEnabled_);
    }

    /* ============ setLiquidityProvider ============ */

    function test_setLiquidityProvider_onlyHookManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setLiquidityProvider(alice, true);
    }

    function test_setLiquidityProvider_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroLiquidityProvider.selector));

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(address(0), true);
    }

    function test_setLiquidityProvider_noChange() public {
        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(alice, false);

        assertFalse(allowlistHook.isLiquidityProviderAllowed(alice));
    }

    function test_setLiquidityProvider() public {
        vm.expectEmit();
        emit IAllowlistHook.LiquidityProviderSet(alice, true);

        vm.prank(hookManager);
        allowlistHook.setLiquidityProvider(alice, true);

        assertTrue(allowlistHook.isLiquidityProviderAllowed(alice));
    }

    function testFuzz_setLiquidityProvider(address liquidityProvider_, bool isAllowed_, uint256 index_) public {
        address caller = _getUser(index_);

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (liquidityProvider_ == address(0)) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroLiquidityProvider.selector));
                // Will return early if the status of the liquidity provider is the same as the current one
            } else if (allowlistHook.isLiquidityProviderAllowed(liquidityProvider_) != isAllowed_) {
                vm.expectEmit();
                emit IAllowlistHook.LiquidityProviderSet(liquidityProvider_, isAllowed_);
            }
        }

        vm.prank(caller);
        allowlistHook.setLiquidityProvider(liquidityProvider_, isAllowed_);

        if (caller != hookManager || liquidityProvider_ == address(0)) return;

        assertEq(allowlistHook.isLiquidityProviderAllowed(liquidityProvider_), isAllowed_);
    }

    /* ============ setLiquidityProviders ============ */

    function test_setLiquidityProviders_onlyHookManager() public {
        address[] memory liquidityProviders_ = new address[](3);
        liquidityProviders_[0] = alice;
        liquidityProviders_[1] = bob;
        liquidityProviders_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setLiquidityProviders(liquidityProviders_, statuses_);
    }

    function test_setLiquidityProviders_arrayLengthMismatch() public {
        address[] memory liquidityProviders_ = new address[](3);
        liquidityProviders_[0] = alice;
        liquidityProviders_[1] = bob;
        liquidityProviders_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(hookManager);
        allowlistHook.setLiquidityProviders(liquidityProviders_, statuses_);
    }

    function test_setLiquidityProviders() public {
        address[] memory liquidityProviders_ = new address[](3);
        liquidityProviders_[0] = alice;
        liquidityProviders_[1] = bob;
        liquidityProviders_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(hookManager);
        allowlistHook.setLiquidityProviders(liquidityProviders_, statuses_);

        assertTrue(allowlistHook.isLiquidityProviderAllowed(alice));
        assertFalse(allowlistHook.isLiquidityProviderAllowed(bob));
        assertTrue(allowlistHook.isLiquidityProviderAllowed(carol));
    }

    function testFuzz_setLiquidityProviders(uint8 seed_, uint8 len_, uint256 index_) public {
        address caller = _getUser(index_);
        address[] memory liquidityProviders = _generateAddressArray(seed_, len_);
        bool[] memory isAllowed = _generateBooleanArray(seed_, len_);

        uint256 liquidityProvidersLength = liquidityProviders.length;
        uint256 isAllowedLength = isAllowed.length;
        uint64 revertCount;

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (liquidityProvidersLength != isAllowedLength) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ArrayLengthMismatch.selector));
            } else {
                for (uint256 i; i < liquidityProvidersLength; ++i) {
                    if (liquidityProviders[i] == address(0)) {
                        revertCount++;
                    }
                }
            }
        }

        if (revertCount != 0) {
            vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroLiquidityProvider.selector), revertCount);
        }

        vm.prank(caller);
        allowlistHook.setLiquidityProviders(liquidityProviders, isAllowed);

        if (caller != hookManager || liquidityProvidersLength != isAllowedLength || revertCount != 0) return;

        for (uint256 j; j < liquidityProvidersLength; ++j) {
            assertEq(allowlistHook.isLiquidityProviderAllowed(liquidityProviders[j]), isAllowed[j]);
        }
    }

    /* ============ setSwapper ============ */

    function test_setSwapper_onlyHookManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setSwapper(alice, true);
    }

    function test_setSwapper_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapper.selector));

        vm.prank(hookManager);
        allowlistHook.setSwapper(address(0), true);
    }

    function test_setSwapper_noChange() public {
        vm.prank(hookManager);
        allowlistHook.setSwapper(alice, false);

        assertFalse(allowlistHook.isSwapperAllowed(alice));
    }

    function test_setSwapper() public {
        vm.expectEmit();
        emit IAllowlistHook.SwapperSet(alice, true);

        vm.prank(hookManager);
        allowlistHook.setSwapper(alice, true);

        assertTrue(allowlistHook.isSwapperAllowed(alice));
    }

    function testFuzz_setSwapper(address swapper_, bool isAllowed_, uint256 index_) public {
        address caller = _getUser(index_);

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (swapper_ == address(0)) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapper.selector));
                // Will return early if the status of the liquidity provider is the same as the current one
            } else if (allowlistHook.isSwapperAllowed(swapper_) != isAllowed_) {
                vm.expectEmit();
                emit IAllowlistHook.SwapperSet(swapper_, isAllowed_);
            }
        }

        vm.prank(caller);
        allowlistHook.setSwapper(swapper_, isAllowed_);

        if (caller != hookManager || swapper_ == address(0)) return;

        assertEq(allowlistHook.isSwapperAllowed(swapper_), isAllowed_);
    }

    /* ============ setSwappers ============ */

    function test_setSwappers_onlyHookManager() public {
        address[] memory swappers_ = new address[](3);
        swappers_[0] = alice;
        swappers_[1] = bob;
        swappers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setSwappers(swappers_, statuses_);
    }

    function test_setSwappers_arrayLengthMismatch() public {
        address[] memory swappers_ = new address[](3);
        swappers_[0] = alice;
        swappers_[1] = bob;
        swappers_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(hookManager);
        allowlistHook.setSwappers(swappers_, statuses_);
    }

    function test_setSwappers() public {
        address[] memory swappers_ = new address[](3);
        swappers_[0] = alice;
        swappers_[1] = bob;
        swappers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(hookManager);
        allowlistHook.setSwappers(swappers_, statuses_);

        assertTrue(allowlistHook.isSwapperAllowed(alice));
        assertFalse(allowlistHook.isSwapperAllowed(bob));
        assertTrue(allowlistHook.isSwapperAllowed(carol));
    }

    function testFuzz_setSwappers(uint8 seed_, uint8 len_, uint256 index_) public {
        address caller = _getUser(index_);
        address[] memory swappers = _generateAddressArray(seed_, len_);
        bool[] memory isAllowed = _generateBooleanArray(seed_, len_);

        uint256 swappersLength = swappers.length;
        uint256 isAllowedLength = isAllowed.length;
        uint64 revertCount;

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (swappersLength != isAllowedLength) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ArrayLengthMismatch.selector));
            } else {
                for (uint256 i; i < swappersLength; ++i) {
                    if (swappers[i] == address(0)) {
                        revertCount++;
                    }
                }
            }
        }

        if (revertCount != 0) {
            vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapper.selector), revertCount);
        }

        vm.prank(caller);
        allowlistHook.setSwappers(swappers, isAllowed);

        if (caller != hookManager || swappersLength != isAllowedLength || revertCount != 0) return;

        for (uint256 j; j < swappersLength; ++j) {
            assertEq(allowlistHook.isSwapperAllowed(swappers[j]), isAllowed[j]);
        }
    }

    /* ============ setPositionManager ============ */

    function test_setPositionManager_onlyHookManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setPositionManager(mockPositionManager, true);
    }

    function test_setPositionManager_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroPositionManager.selector));

        vm.prank(hookManager);
        allowlistHook.setPositionManager(address(0), true);
    }

    function test_setPositionManager_noChange() public {
        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.FORBIDDEN)
        );

        vm.expectEmit();
        emit IAllowlistHook.PositionManagerSet(mockPositionManager, true);

        vm.prank(hookManager);
        allowlistHook.setPositionManager(mockPositionManager, true);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );

        vm.prank(hookManager);
        allowlistHook.setPositionManager(mockPositionManager, true);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );
    }

    function test_setPositionManager() public {
        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.FORBIDDEN)
        );

        vm.expectEmit();
        emit IAllowlistHook.PositionManagerSet(mockPositionManager, true);

        vm.prank(hookManager);
        allowlistHook.setPositionManager(mockPositionManager, true);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );

        vm.prank(hookManager);
        allowlistHook.setPositionManager(mockPositionManager, false);

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(mockPositionManager)),
            uint8(IAllowlistHook.PositionManagerStatus.REDUCE_ONLY)
        );
    }

    function testFuzz_setPositionManager(address positionManager_, bool isAllowed_, uint256 index_) public {
        address caller = _getUser(index_);
        uint8 initialStatus = uint8(allowlistHook.getPositionManagerStatus(positionManager_));

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (positionManager_ == address(0)) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroPositionManager.selector));
            } else if (
                // Will return early if the status of the position manager is the same as the current one
                (initialStatus == uint8(0) && isAllowed_) ||
                (initialStatus == uint8(1) && !isAllowed_) ||
                (initialStatus == uint8(2) && !isAllowed_)
            ) {
                vm.expectEmit();
                emit IAllowlistHook.PositionManagerSet(positionManager_, isAllowed_);
            }
        }

        vm.prank(caller);
        allowlistHook.setPositionManager(positionManager_, isAllowed_);

        if (caller != hookManager || positionManager_ == address(0)) return;

        assertEq(
            uint8(allowlistHook.getPositionManagerStatus(positionManager_)),
            initialStatus == uint8(0) && !isAllowed_
                ? uint8(IAllowlistHook.PositionManagerStatus.FORBIDDEN)
                : isAllowed_
                    ? uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
                    : uint8(IAllowlistHook.PositionManagerStatus.REDUCE_ONLY)
        );
    }

    /* ============ setPositionManagers ============ */

    function test_setPositionManagers_onlyHookManager() public {
        address[] memory positionManagers_ = new address[](3);
        positionManagers_[0] = alice;
        positionManagers_[1] = bob;
        positionManagers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setPositionManagers(positionManagers_, statuses_);
    }

    function test_setPositionManagers_arrayLengthMismatch() public {
        address[] memory positionManagers_ = new address[](3);
        positionManagers_[0] = alice;
        positionManagers_[1] = bob;
        positionManagers_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(hookManager);
        allowlistHook.setPositionManagers(positionManagers_, statuses_);
    }

    function test_setPositionManagers() public {
        address[] memory positionManagers_ = new address[](3);
        positionManagers_[0] = alice;
        positionManagers_[1] = bob;
        positionManagers_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(hookManager);
        allowlistHook.setPositionManagers(positionManagers_, statuses_);

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

    function testFuzz_setPositionManagers(uint8 seed_, uint8 len_, uint256 index_) public {
        address caller = _getUser(index_);
        address[] memory positionManagers = _generateAddressArray(seed_, len_);
        bool[] memory isAllowed = _generateBooleanArray(seed_, len_);
        uint8[] memory initialStatuses = new uint8[](len_);

        uint256 positionManagersLength = positionManagers.length;
        uint256 isAllowedLength = isAllowed.length;
        uint64 revertCount;

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (positionManagersLength != isAllowedLength) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ArrayLengthMismatch.selector));
            } else {
                for (uint256 i; i < positionManagersLength; ++i) {
                    address positionManager = positionManagers[i];

                    if (positionManagers[i] == address(0)) {
                        revertCount++;
                    }

                    initialStatuses[i] = uint8(allowlistHook.getPositionManagerStatus(positionManager));
                }
            }
        }

        if (revertCount != 0) {
            vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroPositionManager.selector), revertCount);
        }

        vm.prank(caller);
        allowlistHook.setPositionManagers(positionManagers, isAllowed);

        if (caller != hookManager || positionManagersLength != isAllowedLength || revertCount != 0) return;

        for (uint256 j; j < positionManagersLength; ++j) {
            assertEq(
                uint8(allowlistHook.getPositionManagerStatus(positionManagers[j])),
                initialStatuses[j] == uint8(0) && !isAllowed[j]
                    ? uint8(IAllowlistHook.PositionManagerStatus.FORBIDDEN)
                    : isAllowed[j]
                        ? uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
                        : uint8(IAllowlistHook.PositionManagerStatus.REDUCE_ONLY)
            );
        }
    }

    /* ============ setSwapRouter ============ */

    function test_setSwapRouter_onlyHookManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setSwapRouter(address(mockRouter), true);
    }

    function test_setSwapRouter_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapRouter.selector));

        vm.prank(hookManager);
        allowlistHook.setSwapRouter(address(0), true);
    }

    function test_setSwapRouter_noChange() public {
        assertFalse(allowlistHook.isSwapRouterTrusted(address(mockRouter)));

        vm.expectEmit();
        emit IAllowlistHook.SwapRouterSet(address(mockRouter), true);

        vm.prank(hookManager);
        allowlistHook.setSwapRouter(address(mockRouter), true);

        assertTrue(allowlistHook.isSwapRouterTrusted(address(mockRouter)));

        vm.prank(hookManager);
        allowlistHook.setSwapRouter(address(mockRouter), true);

        assertTrue(allowlistHook.isSwapRouterTrusted(address(mockRouter)));
    }

    function test_setSwapRouter() public {
        assertFalse(allowlistHook.isSwapRouterTrusted(address(mockRouter)));

        vm.expectEmit();
        emit IAllowlistHook.SwapRouterSet(address(mockRouter), true);

        vm.prank(hookManager);
        allowlistHook.setSwapRouter(address(mockRouter), true);

        assertTrue(allowlistHook.isSwapRouterTrusted(address(mockRouter)));
    }

    function testFuzz_setSwapRouter(address swapRouter_, bool isAllowed_, uint256 index_) public {
        address caller = _getUser(index_);

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (swapRouter_ == address(0)) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapRouter.selector));
            } else if (
                // Will return early if the status of the swap router is the same as the current one
                allowlistHook.isSwapRouterTrusted(swapRouter_) != isAllowed_
            ) {
                vm.expectEmit();
                emit IAllowlistHook.SwapRouterSet(swapRouter_, isAllowed_);
            }
        }

        vm.prank(caller);
        allowlistHook.setSwapRouter(swapRouter_, isAllowed_);

        if (caller != hookManager || swapRouter_ == address(0)) return;

        assertEq(allowlistHook.isSwapRouterTrusted(swapRouter_), isAllowed_);
    }

    /* ============ setSwapRouters ============ */

    function test_setSwapRouters_onlyHookManager() public {
        address[] memory swapRouters_ = new address[](3);
        swapRouters_[0] = alice;
        swapRouters_[1] = bob;
        swapRouters_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.setSwapRouters(swapRouters_, statuses_);
    }

    function test_setSwapRouters_arrayLengthMismatch() public {
        address[] memory swapRouters_ = new address[](3);
        swapRouters_[0] = alice;
        swapRouters_[1] = bob;
        swapRouters_[2] = carol;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = false;

        vm.expectRevert(IAllowlistHook.ArrayLengthMismatch.selector);

        vm.prank(hookManager);
        allowlistHook.setSwapRouters(swapRouters_, statuses_);
    }

    function test_setSwapRouters() public {
        address[] memory swapRouters_ = new address[](3);
        swapRouters_[0] = alice;
        swapRouters_[1] = bob;
        swapRouters_[2] = carol;

        bool[] memory statuses_ = new bool[](3);
        statuses_[0] = true;
        statuses_[1] = false;
        statuses_[2] = true;

        vm.prank(hookManager);
        allowlistHook.setSwapRouters(swapRouters_, statuses_);

        assertTrue(allowlistHook.isSwapRouterTrusted(alice));
        assertFalse(allowlistHook.isSwapRouterTrusted(bob));
        assertTrue(allowlistHook.isSwapRouterTrusted(carol));
    }

    function testFuzz_setSwapRouters(uint8 seed_, uint8 len_, uint256 index_) public {
        address caller = _getUser(index_);
        address[] memory swapRouters = _generateAddressArray(seed_, len_);
        bool[] memory isAllowed = _generateBooleanArray(seed_, len_);

        uint256 swapRoutersLength = swapRouters.length;
        uint256 isAllowedLength = isAllowed.length;
        uint64 revertCount;

        if (caller != hookManager) {
            vm.expectRevert(
                abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _MANAGER_ROLE)
            );
        } else {
            if (swapRoutersLength != isAllowedLength) {
                vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ArrayLengthMismatch.selector));
            } else {
                for (uint256 i; i < swapRoutersLength; ++i) {
                    if (swapRouters[i] == address(0)) {
                        revertCount++;
                    }
                }
            }
        }

        if (revertCount != 0) {
            vm.expectRevert(abi.encodeWithSelector(IAllowlistHook.ZeroSwapRouter.selector), revertCount);
        }

        vm.prank(caller);
        allowlistHook.setSwapRouters(swapRouters, isAllowed);

        if (caller != hookManager || swapRoutersLength != isAllowedLength || revertCount != 0) return;

        for (uint256 j; j < swapRoutersLength; ++j) {
            assertEq(allowlistHook.isSwapRouterTrusted(swapRouters[j]), isAllowed[j]);
        }
    }

    /* ============ upgrade ============ */

    function test_upgrade_onlyUpgrader() public {
        address v2implementation = address(new AllowlistHookUpgrade());

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _UPGRADER_ROLE)
        );

        vm.prank(alice);
        allowlistHook.upgradeToAndCall(v2implementation, "");
    }

    function test_upgrade() public {
        address v2implementation = address(new AllowlistHookUpgrade());

        vm.prank(upgrader);
        allowlistHook.upgradeToAndCall(v2implementation, "");

        assertEq(AllowlistHookUpgrade(address(allowlistHook)).bar(), 1);
    }
}
