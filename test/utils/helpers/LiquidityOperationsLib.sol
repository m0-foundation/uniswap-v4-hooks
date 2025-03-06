// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IPositionManager } from "../../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { Actions } from "../../../lib/v4-periphery/src/libraries/Actions.sol";

import { Planner, Plan } from "../../../lib/v4-periphery/test/shared/Planner.sol";
import { PositionConfig } from "../../../lib/v4-periphery/test/shared/PositionConfig.sol";

library LiquidityOperationsLib {
    uint128 public constant MAX_SLIPPAGE_INCREASE = type(uint128).max;
    uint128 public constant MIN_SLIPPAGE_DECREASE = 0 wei;

    function mint(
        IPositionManager lpm_,
        PositionConfig memory config_,
        uint256 liquidity_,
        address recipient_,
        bytes memory hookData_
    ) internal {
        bytes memory calls_ = getMintEncoded(config_, liquidity_, recipient_, hookData_);
        lpm_.modifyLiquidities(calls_, block.timestamp + 1);
    }

    function increaseLiquidity(
        IPositionManager lpm_,
        uint256 tokenId_,
        PositionConfig memory config_,
        uint256 liquidityToAdd_,
        bytes memory hookData_
    ) internal {
        bytes memory calls_ = getIncreaseEncoded(tokenId_, config_, liquidityToAdd_, hookData_);
        lpm_.modifyLiquidities(calls_, block.timestamp + 1);
    }

    // do not make external call before unlockAndExecute, allows us to test reverts
    function decreaseLiquidity(
        IPositionManager lpm_,
        uint256 tokenId_,
        PositionConfig memory config_,
        uint256 liquidityToRemove_,
        bytes memory hookData_
    ) internal {
        bytes memory calls_ = getDecreaseEncoded(tokenId_, config_, liquidityToRemove_, hookData_);
        lpm_.modifyLiquidities(calls_, block.timestamp + 1);
    }

    // Helper functions for getting encoded calldata for .modifyLiquidities() or .modifyLiquiditiesWithoutUnlock()
    function getMintEncoded(
        PositionConfig memory config,
        uint256 liquidity,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        return getMintEncoded(config, liquidity, MAX_SLIPPAGE_INCREASE, MAX_SLIPPAGE_INCREASE, recipient, hookData);
    }

    function getMintEncoded(
        PositionConfig memory config,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        Plan memory planner = Planner.init();
        planner.add(
            Actions.MINT_POSITION,
            abi.encode(
                config.poolKey,
                config.tickLower,
                config.tickUpper,
                liquidity,
                amount0Max,
                amount1Max,
                recipient,
                hookData
            )
        );

        return planner.finalizeModifyLiquidityWithClose(config.poolKey);
    }

    function getIncreaseEncoded(
        uint256 tokenId,
        PositionConfig memory config,
        uint256 liquidityToAdd,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        // max slippage
        return
            getIncreaseEncoded(tokenId, config, liquidityToAdd, MAX_SLIPPAGE_INCREASE, MAX_SLIPPAGE_INCREASE, hookData);
    }

    function getIncreaseEncoded(
        uint256 tokenId,
        PositionConfig memory config,
        uint256 liquidityToAdd,
        uint128 amount0Max,
        uint128 amount1Max,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        Plan memory planner = Planner.init();
        planner.add(Actions.INCREASE_LIQUIDITY, abi.encode(tokenId, liquidityToAdd, amount0Max, amount1Max, hookData));
        return planner.finalizeModifyLiquidityWithClose(config.poolKey);
    }

    function getDecreaseEncoded(
        uint256 tokenId,
        PositionConfig memory config,
        uint256 liquidityToRemove,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        return
            getDecreaseEncoded(
                tokenId,
                config,
                liquidityToRemove,
                MIN_SLIPPAGE_DECREASE,
                MIN_SLIPPAGE_DECREASE,
                hookData
            );
    }

    function getDecreaseEncoded(
        uint256 tokenId,
        PositionConfig memory config,
        uint256 liquidityToRemove,
        uint128 amount0Min,
        uint128 amount1Min,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        Plan memory planner = Planner.init();
        planner.add(
            Actions.DECREASE_LIQUIDITY,
            abi.encode(tokenId, liquidityToRemove, amount0Min, amount1Min, hookData)
        );
        return planner.finalizeModifyLiquidityWithClose(config.poolKey);
    }
}
