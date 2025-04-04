// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";

import { BalanceDelta, toBalanceDelta } from "../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";

import { IBaseHook } from "../src/interfaces/IBaseHook.sol";

import { BaseHookUpgradeableHarness } from "./harness/BaseHookUpgradeableHarness.sol";

import { BaseTest } from "./utils/BaseTest.sol";

contract BaseHookUpgradeableTest is BaseTest {
    BaseHookUpgradeableHarness public baseHookUpgradeableImplementation = new BaseHookUpgradeableHarness();
    BaseHookUpgradeableHarness public baseHookUpgradeable;

    uint160 public flags =
        uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.AFTER_INITIALIZE_FLAG |
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
                Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG |
                Hooks.BEFORE_DONATE_FLAG |
                Hooks.AFTER_DONATE_FLAG |
                Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG |
                Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG |
                Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG |
                Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG
        );

    function setUp() public override {
        super.setUp();

        // Deploy the proxy contract to the mined address
        bytes memory implementationInitializeCall = abi.encodeCall(
            BaseHookUpgradeableHarness.initialize,
            (address(manager))
        );

        bytes memory proxyConstructorArgs = abi.encode(baseHookUpgradeableImplementation, implementationInitializeCall);

        address namespacedFlags = address(flags ^ (0x4444 << 144)); // Namespace the hook to avoid collisions

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        baseHookUpgradeable = BaseHookUpgradeableHarness(namespacedFlags);
        Hooks.validateHookPermissions(baseHookUpgradeable, baseHookUpgradeable.getHookPermissions());
    }

    /* ============ beforeInitialize ============ */

    function test_beforeInitialize_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.beforeInitialize(alice, key, 0);
    }

    function test_beforeInitialize_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.beforeInitialize(alice, key, 0);
    }

    /* ============ afterInitialize ============ */

    function test_afterInitialize_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.afterInitialize(alice, key, 0, 0);
    }

    function test_afterInitialize_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.afterInitialize(alice, key, 0, 0);
    }

    /* ============ beforeAddLiquidity ============ */

    function test_beforeAddLiquidity_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.beforeAddLiquidity(alice, key, IPoolManager.ModifyLiquidityParams(0, 0, 0, ""), "");
    }

    function test_beforeAddLiquidity_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.beforeAddLiquidity(alice, key, IPoolManager.ModifyLiquidityParams(0, 0, 0, ""), "");
    }

    /* ============ beforeRemoveLiquidity ============ */

    function test_beforeRemoveLiquidity_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.beforeRemoveLiquidity(alice, key, IPoolManager.ModifyLiquidityParams(0, 0, 0, ""), "");
    }

    function test_beforeRemoveLiquidity_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.beforeRemoveLiquidity(alice, key, IPoolManager.ModifyLiquidityParams(0, 0, 0, ""), "");
    }

    /* ============ afterAddLiquidity ============ */

    function test_afterAddLiquidity_onlyPoolManager() public {
        BalanceDelta balanceDelta = toBalanceDelta(0, 0);

        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.afterAddLiquidity(
            alice,
            key,
            IPoolManager.ModifyLiquidityParams(0, 0, 0, ""),
            balanceDelta,
            balanceDelta,
            ""
        );
    }

    function test_afterAddLiquidity_hookNotImplemented() public {
        BalanceDelta balanceDelta = toBalanceDelta(0, 0);

        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.afterAddLiquidity(
            alice,
            key,
            IPoolManager.ModifyLiquidityParams(0, 0, 0, ""),
            balanceDelta,
            balanceDelta,
            ""
        );
    }

    /* ============ afterRemoveLiquidity ============ */

    function test_afterRemoveLiquidity_onlyPoolManager() public {
        BalanceDelta balanceDelta = toBalanceDelta(0, 0);

        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.afterRemoveLiquidity(
            alice,
            key,
            IPoolManager.ModifyLiquidityParams(0, 0, 0, ""),
            balanceDelta,
            balanceDelta,
            ""
        );
    }

    function test_afterRemoveLiquidity_hookNotImplemented() public {
        BalanceDelta balanceDelta = toBalanceDelta(0, 0);

        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.afterRemoveLiquidity(
            alice,
            key,
            IPoolManager.ModifyLiquidityParams(0, 0, 0, ""),
            balanceDelta,
            balanceDelta,
            ""
        );
    }

    /* ============ beforeSwap ============ */

    function test_beforeSwap_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.beforeSwap(alice, key, IPoolManager.SwapParams(false, 0, 0), "");
    }

    function test_beforeSwap_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.beforeSwap(alice, key, IPoolManager.SwapParams(false, 0, 0), "");
    }

    /* ============ afterSwap ============ */

    function test_afterSwap_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.afterSwap(alice, key, IPoolManager.SwapParams(false, 0, 0), toBalanceDelta(0, 0), "");
    }

    function test_afterSwap_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.afterSwap(alice, key, IPoolManager.SwapParams(false, 0, 0), toBalanceDelta(0, 0), "");
    }

    /* ============ beforeDonate ============ */

    function test_beforeDonate_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.beforeDonate(alice, key, 0, 0, "");
    }

    function test_beforeDonate_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.beforeDonate(alice, key, 0, 0, "");
    }

    /* ============ afterDonate ============ */

    function test_afterDonate_onlyPoolManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.NotPoolManager.selector));

        vm.prank(alice);
        baseHookUpgradeable.afterDonate(alice, key, 0, 0, "");
    }

    function test_afterDonate_hookNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseHook.HookNotImplemented.selector));

        vm.prank(address(manager));
        baseHookUpgradeable.afterDonate(alice, key, 0, 0, "");
    }
}
