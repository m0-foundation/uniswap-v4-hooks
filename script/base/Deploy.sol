// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
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

contract Deploy is Config {
    function _deployTickRangeHook(address owner_, DeployConfig memory config_) internal returns (IHooks) {
        uint160 flags_ = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress_, bytes32 salt_) = HookMiner.find(
            config_.create2Deployer,
            flags_,
            type(TickRangeHook).creationCode,
            abi.encode(address(config_.poolManager), config_.tickLowerBound, config_.tickUpperBound, owner_)
        );

        // Deploy the hook using CREATE2
        TickRangeHook tickRangeHook_ = new TickRangeHook{ salt: salt_ }(
            address(config_.poolManager),
            config_.tickLowerBound,
            config_.tickUpperBound,
            owner_
        );

        require(address(tickRangeHook_) == hookAddress_, "TickRangeHook: hook address mismatch");

        return IHooks(address(tickRangeHook_));
    }

    function _deployAllowlistHook(address owner_, DeployConfig memory config_) internal returns (IHooks) {
        uint160 flags_ = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress_, bytes32 salt_) = HookMiner.find(
            config_.create2Deployer,
            flags_,
            type(AllowlistHook).creationCode,
            abi.encode(
                address(config_.posm),
                config_.swapRouter,
                address(config_.poolManager),
                config_.tickLowerBound,
                config_.tickUpperBound,
                owner_
            )
        );

        // Deploy the hook using CREATE2
        AllowlistHook allowlistHook_ = new AllowlistHook{ salt: salt_ }(
            address(config_.posm),
            config_.swapRouter,
            address(config_.poolManager),
            config_.tickLowerBound,
            config_.tickUpperBound,
            owner_
        );

        require(address(allowlistHook_) == hookAddress_, "AllowlistHook: hook address mismatch");

        return IHooks(address(allowlistHook_));
    }

    function _deployPool(DeployConfig memory config_, IHooks hook_) internal returns (PoolKey memory pool_) {
        (Currency currency0_, Currency currency1_) = _sortCurrencies(address(config_.usdc), address(config_.wrappedM));

        pool_ = PoolKey({
            currency0: currency0_,
            currency1: currency1_,
            fee: config_.fee,
            tickSpacing: config_.tickSpacing,
            hooks: hook_
        });

        config_.poolManager.initialize(pool_, TickMath.getSqrtPriceAtTick(0));
    }

    function _logPoolDeployment(Vm.Log[] memory logs_) internal pure {
        for (uint i_ = 0; i_ < logs_.length; ++i_) {
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

    function _sortCurrencies(
        address tokenA_,
        address tokenB_
    ) internal pure returns (Currency currency0_, Currency currency1_) {
        (currency0_, currency1_) = tokenA_ < tokenB_
            ? (Currency.wrap(tokenA_), Currency.wrap(tokenB_))
            : (Currency.wrap(tokenB_), Currency.wrap(tokenA_));
    }
}
