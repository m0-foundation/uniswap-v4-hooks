// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { Upgrades } from "../../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import { Options } from "../../lib/openzeppelin-foundry-upgrades/src/Options.sol";
import { Utils } from "../../lib/openzeppelin-foundry-upgrades/src/internal/Utils.sol";

import {
    ERC1967Proxy
} from "../../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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
        address deployer_,
        address admin_,
        address manager_,
        address upgrader_,
        DeployConfig memory config_
    ) internal returns (address, address) {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
            (config_.poolManager, config_.tickLowerBound, config_.tickUpperBound, admin_, manager_, upgrader_)
        );

        (address tickRangeHook, address hookAddress, bytes32 salt) = _mineHook(
            deployer_,
            implementationInitializeCall,
            uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG)
        );

        address proxyAddress = _deployUUPSProxy("TickRangeHook.sol:TickRangeHook", implementationInitializeCall, salt);
        TickRangeHook tickRangeHookProxy = TickRangeHook(proxyAddress);

        // Check that our proxy has an address that encodes the correct permissions
        Hooks.validateHookPermissions(tickRangeHookProxy, tickRangeHookProxy.getHookPermissions());

        require(proxyAddress == hookAddress, "TickRangeHook: hook address mismatch");

        console.log("TickRangeHook deployed!");
        console.log("TickRangeHook implementation:", tickRangeHook);
        console.log("TickRangeHook proxy:", proxyAddress);

        return (tickRangeHook, proxyAddress);
    }

    function _deployAllowlistHook(
        address deployer_,
        address admin_,
        address manager_,
        address upgrader_,
        DeployConfig memory config_
    ) internal returns (address, address) {
        bytes memory implementationInitializeCall = abi.encodeCall(
            AllowlistHook.initialize,
            (
                config_.posm,
                config_.swapRouter,
                config_.poolManager,
                config_.tickLowerBound,
                config_.tickUpperBound,
                admin_,
                manager_,
                upgrader_
            )
        );

        (address allowlistHook, address hookAddress, bytes32 salt) = _mineHook(
            deployer_,
            implementationInitializeCall,
            uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG)
        );

        address proxyAddress = _deployUUPSProxy("AllowlistHook.sol:AllowlistHook", implementationInitializeCall, salt);
        AllowlistHook allowlistHookProxy = AllowlistHook(proxyAddress);

        // Check that our proxy has an address that encodes the correct permissions
        Hooks.validateHookPermissions(allowlistHookProxy, allowlistHookProxy.getHookPermissions());

        require(proxyAddress == hookAddress, "AllowlistHook: hook address mismatch");

        console.log("AllowlistHook deployed!");
        console.log("AllowlistHook implementation:", allowlistHook);
        console.log("AllowlistHook proxy:", proxyAddress);

        return (allowlistHook, proxyAddress);
    }

    function _mineHook(
        address deployer_,
        bytes memory implementationInitializeCall_,
        uint160 flags_
    ) internal view returns (address implementationAddress, address hookAddress, bytes32 salt) {
        // Compute the address where the implementation will be deployed
        implementationAddress = vm.computeCreateAddress(deployer_, vm.getNonce(deployer_));

        // Mine a salt that will produce a hook address with the correct flags
        (hookAddress, salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags_,
            type(ERC1967Proxy).creationCode,
            abi.encode(implementationAddress, implementationInitializeCall_)
        );
    }

    /**
     * @dev Deploys a UUPS proxy with a salt using the given contract as the implementation.
     * @param contractName_ Name of the contract to use as the implementation,
     * e.g. "MyContract.sol" or "MyContract.sol:MyContract" or artifact path relative to the project root directory.
     * @param initializerData_ Encoded calldata of the initializer function to call during creation of the proxy.
     * @param salt_ Salt to use for the CREATE2 deployment of the proxy.
     * @return Proxy address.
     */
    function _deployUUPSProxy(
        string memory contractName_,
        bytes memory initializerData_,
        bytes32 salt_
    ) internal returns (address) {
        Options memory opts;
        address implementation = Upgrades.deployImplementation(contractName_, opts);

        return
            _deploy(
                "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
                abi.encode(implementation, initializerData_),
                salt_
            );
    }

    function _deploy(
        string memory contractName_,
        bytes memory constructorData_,
        bytes32 salt_
    ) internal returns (address) {
        bytes memory creationCode = Vm(Utils.CHEATCODE_ADDRESS).getCode(contractName_);
        address deployedAddress = _deployFromBytecodeWithSalt(abi.encodePacked(creationCode, constructorData_), salt_);

        if (deployedAddress == address(0)) {
            revert(
                string(
                    abi.encodePacked(
                        "Failed to deploy contract ",
                        contractName_,
                        ' using constructor data "',
                        string(constructorData_),
                        '"'
                    )
                )
            );
        }

        return deployedAddress;
    }

    function _deployFromBytecodeWithSalt(bytes memory bytecode_, bytes32 salt_) internal returns (address) {
        address addr;

        /// @solidity memory-safe-assembly
        assembly {
            addr := create2(0, add(bytecode_, 32), mload(bytecode_), salt_)
        }

        return addr;
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

        IPoolManager(config_.poolManager).initialize(pool_, TickMath.getSqrtPriceAtTick(0));
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

    function _sortCurrencies(
        address tokenA_,
        address tokenB_
    ) internal pure returns (Currency currency0_, Currency currency1_) {
        (currency0_, currency1_) = tokenA_ < tokenB_
            ? (Currency.wrap(tokenA_), Currency.wrap(tokenB_))
            : (Currency.wrap(tokenB_), Currency.wrap(tokenA_));
    }
}
