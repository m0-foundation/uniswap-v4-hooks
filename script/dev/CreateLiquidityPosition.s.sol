// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";

import { LiquidityOperationsLib } from "../../test/utils/helpers/LiquidityOperationsLib.sol";

import { UniswapV4Helpers } from "./helpers/UniswapV4Helpers.sol";

contract CreateLiquidityPosition is UniswapV4Helpers {
    using LiquidityOperationsLib for IPositionManager;

    function run() public {
        address caller = _getCaller();

        address token0 = vm.envAddress("TOKEN_0");
        address token1 = vm.envAddress("TOKEN_1");

        int24 tickLowerBound = int24(vm.envInt("TICK_LOWER_BOUND"));
        int24 tickUpperBound = int24(vm.envInt("TICK_UPPER_BOUND"));

        DeployConfig memory config = _getDeployConfig(block.chainid, token0, token1, tickLowerBound, tickUpperBound);

        PoolKey memory poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            hooks: IHooks(vm.envAddress("UNISWAP_HOOK"))
        });

        (, int24 currentTick, , ) = _getPoolState(poolKey);

        uint128 liquidity = _getLiquidityForAmounts(
            vm.envUint("AMOUNT_0"),
            vm.envUint("AMOUNT_1"),
            currentTick,
            tickLowerBound,
            tickUpperBound
        );

        if (liquidity == 0) revert("Zero liquidity amount.");

        vm.startBroadcast(caller);

        _approvePermit2(caller, token0, config.posm);
        _approvePermit2(caller, token1, config.posm);

        IPositionManager(POSM_ETHEREUM).mint(
            PositionConfig({ poolKey: poolKey, tickLower: tickLowerBound, tickUpper: tickUpperBound }),
            liquidity,
            caller,
            ""
        );

        vm.stopBroadcast();
    }

    function _getCaller() internal returns (address) {
        address fireblocksSender = vm.envOr("FIREBLOCKS_SENDER", address(0));
        return fireblocksSender == address(0) ? vm.rememberKey(vm.envUint("PRIVATE_KEY")) : fireblocksSender;
    }
}
