// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";

import { LiquidityOperationsLib } from "../../test/utils/helpers/LiquidityOperationsLib.sol";

import { UniswapV4Helpers } from "./helpers/UniswapV4Helpers.sol";

contract ModifyLiquidityPosition is UniswapV4Helpers {
    using LiquidityOperationsLib for IPositionManager;

    function run() public {
        address caller = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        uint256 nftId = vm.envUint("NFT_ID");
        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");
        int24 tickLowerBound = int24(vm.envInt("TICK_LOWER_BOUND"));
        int24 tickUpperBound = int24(vm.envInt("TICK_UPPER_BOUND"));

        DeployConfig memory config = _getDeployConfig(block.chainid, tokenA, tokenB, tickLowerBound, tickUpperBound);

        PoolKey memory poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            hooks: IHooks(vm.envAddress("UNISWAP_HOOK"))
        });

        PositionConfig memory positionConfig = PositionConfig({
            poolKey: poolKey,
            tickLower: tickLowerBound,
            tickUpper: tickUpperBound
        });

        uint128 liquidity = _getLiquidityForAmounts(poolKey, tokenA, tokenB, tickLowerBound, tickUpperBound, caller);

        if (liquidity == 0) revert("Zero liquidity amount.");

        vm.startBroadcast(caller);

        if (vm.envBool("DECREASE_LIQUIDITY")) {
            _decreaseLiquidity(nftId, positionConfig, liquidity);
        } else {
            _approvePermit2(caller, tokenA, config.posm);
            _approvePermit2(caller, tokenB, config.posm);

            _increaseLiquidity(nftId, positionConfig, liquidity);
        }

        vm.stopBroadcast();
    }

    function _decreaseLiquidity(uint256 nftId, PositionConfig memory config, uint128 liquidity) internal {
        IPositionManager(POSM_ETHEREUM).decreaseLiquidity(nftId, config, liquidity, "");
    }

    function _increaseLiquidity(uint256 nftId, PositionConfig memory config, uint128 liquidity) internal {
        IPositionManager(POSM_ETHEREUM).increaseLiquidity(nftId, config, liquidity, "");
    }
}
