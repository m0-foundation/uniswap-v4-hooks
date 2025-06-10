// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { Currency } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolId } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { HookMiner } from "../../lib/v4-periphery/src/utils/HookMiner.sol";
import { AllowlistHook } from "../../src/AllowlistHook.sol";
import { TickRangeHook } from "../../src/TickRangeHook.sol";

import { Config } from "./Config.sol";

contract Deploy is Config, Script {
    function _deployTickRangeHook(
        address admin_,
        address manager_,
        DeployConfig memory config_
    ) internal returns (address) {
        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress_, bytes32 salt_) = HookMiner.find(
            CREATE2_DEPLOYER,
            uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG),
            type(TickRangeHook).creationCode,
            abi.encode(address(config_.poolManager), config_.tickLowerBound, config_.tickUpperBound, admin_, manager_)
        );

        // Deploy the hook using CREATE2
        TickRangeHook tickRangeHook_ = new TickRangeHook{ salt: salt_ }(
            address(config_.poolManager),
            config_.tickLowerBound,
            config_.tickUpperBound,
            admin_,
            manager_
        );

        // Check that our proxy has an address that encodes the correct permissions
        Hooks.validateHookPermissions(tickRangeHook_, tickRangeHook_.getHookPermissions());

        require(address(tickRangeHook_) == hookAddress_, "TickRangeHook: hook address mismatch");

        console.log("TickRangeHook deployed!");
        console.log("Hook address: ", address(tickRangeHook_));

        return address(tickRangeHook_);
    }

    function _deployAllowlistHook(
        address admin_,
        address manager_,
        DeployConfig memory config_
    ) internal returns (address) {
        bytes memory constructorArgs = abi.encode(
            address(config_.posm),
            config_.swapRouter,
            address(config_.poolManager),
            address(config_.serviceManager),
            config_.policyID,
            config_.tickLowerBound,
            config_.tickUpperBound,
            admin_,
            manager_
        );

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress_, bytes32 salt_) = HookMiner.find(
            CREATE2_DEPLOYER,
            uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG),
            type(AllowlistHook).creationCode,
            constructorArgs
        );

        // Deploy the hook using CREATE2
        AllowlistHook allowlistHook_ = new AllowlistHook{ salt: salt_ }(
            address(config_.posm),
            config_.swapRouter,
            address(config_.poolManager),
            address(config_.serviceManager),
            config_.policyID,
            config_.tickLowerBound,
            config_.tickUpperBound,
            admin_,
            manager_
        );

        // Check that our proxy has an address that encodes the correct permissions
        Hooks.validateHookPermissions(allowlistHook_, allowlistHook_.getHookPermissions());

        require(address(allowlistHook_) == hookAddress_, "AllowlistHook: hook address mismatch");

        console.log("AllowlistHook deployed!");
        console.log("Hook address: ", address(allowlistHook_));

        return address(allowlistHook_);
    }

    function _deployPool(DeployConfig memory config_, IHooks hook_) internal returns (PoolKey memory pool_) {
        pool_ = PoolKey({
            currency0: config_.currency0,
            currency1: config_.currency1,
            fee: config_.fee,
            tickSpacing: config_.tickSpacing,
            hooks: hook_
        });

        IPoolManager(config_.poolManager).initialize(pool_, 79230143144055126352967237632); // Sqrt Price at tick 0.5
    }

    function _logPoolDeployment(Vm.Log[] memory logs_) internal pure {
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].topics[0] == IPoolManager.Initialize.selector) {
                (PoolId eventId_, , , , , IHooks eventHooks_, , int24 eventTick_) = abi.decode(
                    logs_[i_].data,
                    (PoolId, Currency, Currency, uint24, int24, IHooks, uint160, int24)
                );

                console.log("Uniswap V4 Pool deployed!");
                console.log("Pool ID:");
                console.logBytes32(PoolId.unwrap(eventId_));
                console.log("Pool initial tick:", eventTick_);
                console.log("Pool hooks:", address(eventHooks_));
            }
        }
    }
}
