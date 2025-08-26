// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { PositionInfo, PositionInfoLibrary } from "../../lib/v4-periphery/src/libraries/PositionInfoLibrary.sol";

import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";

import { LiquidityOperationsLib } from "../../test/utils/helpers/LiquidityOperationsLib.sol";

import { UniswapV4Helpers } from "./helpers/UniswapV4Helpers.sol";

contract ModifyLiquidityPosition is UniswapV4Helpers {
    using LiquidityOperationsLib for IPositionManager;

    function run() public {
        address caller = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint256 tokenId = vm.envUint("TOKEN_ID");

        console.log("Pool and position state before LP modification.");

        (
            PoolKey memory poolKey,
            ,
            address tokenA,
            address tokenB,
            int24 currentTick,
            int24 tickLower,
            int24 tickUpper,

        ) = _getPoolAndPositionState(tokenId);

        PositionConfig memory positionConfig = PositionConfig({
            poolKey: poolKey,
            tickLower: tickLower,
            tickUpper: tickUpper
        });

        uint128 liquidity = _getLiquidityForAmounts(tokenA, tokenB, currentTick, tickLower, tickUpper, caller);

        if (liquidity == 0) revert("Zero liquidity amount.");

        vm.startBroadcast(caller);

        if (vm.envBool("DECREASE_LIQUIDITY")) {
            _decreaseLiquidity(tokenId, positionConfig, liquidity);
        } else {
            _approvePermit2(caller, tokenA, _getDeployConfig(block.chainid, tokenA, tokenB, tickLower, tickUpper).posm);
            _approvePermit2(caller, tokenB, _getDeployConfig(block.chainid, tokenA, tokenB, tickLower, tickUpper).posm);

            _increaseLiquidity(tokenId, positionConfig, liquidity);
        }

        vm.stopBroadcast();

        console.log("Pool and position state after LP modification.");
        _getPoolAndPositionState(tokenId);
    }

    function _decreaseLiquidity(uint256 tokenId, PositionConfig memory positionConfig, uint128 liquidity) internal {
        IPositionManager(POSM_ETHEREUM).decreaseLiquidity(tokenId, positionConfig, liquidity, "");
    }

    function _increaseLiquidity(uint256 tokenId, PositionConfig memory positionConfig, uint128 liquidity) internal {
        IPositionManager(POSM_ETHEREUM).increaseLiquidity(tokenId, positionConfig, liquidity, "");
    }
}
