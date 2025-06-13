// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";

import { IAllowanceTransfer } from "../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Currency, CurrencyLibrary } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { Actions } from "../../lib/v4-periphery/src/libraries/Actions.sol";

import { IV4Router } from "../../lib/v4-periphery/src/interfaces/IV4Router.sol";

import { IUniversalRouterLike } from "../../test/utils/interfaces/IUniversalRouterLike.sol";

import { Deploy } from "../base/Deploy.s.sol";

contract Swap is Deploy {
    using CurrencyLibrary for Currency;

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function run() public {
        address caller = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address hook = vm.envAddress("UNISWAP_HOOK");

        DeployConfig memory config = _getDeployConfig(block.chainid);

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(WRAPPED_M),
            currency1: Currency.wrap(USDC_ETHEREUM),
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            hooks: IHooks(hook)
        });

        IUniversalRouterLike swapRouter = IUniversalRouterLike(config.swapRouter);

        vm.startBroadcast(caller);

        IERC20(USDC_ETHEREUM).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(USDC_ETHEREUM, address(swapRouter), type(uint160).max, type(uint48).max);

        bytes memory commands = abi.encodePacked(uint8(0x10)); // V4 Swap command
        bytes[] memory inputs = new bytes[](1);
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_OUT_SINGLE),
            uint8(Actions.TAKE_ALL),
            uint8(Actions.SETTLE_ALL)
        );

        uint128 swapAmountOut = 1_000_000e6;
        uint128 swapAmountIn = type(uint128).max;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactOutputSingleParams({
                poolKey: poolKey,
                zeroForOne: false,
                amountOut: swapAmountOut,
                amountInMaximum: swapAmountIn,
                hookData: "0x"
            })
        );

        params[1] = abi.encode(poolKey.currency0, swapAmountOut);
        params[2] = abi.encode(poolKey.currency1, swapAmountIn);

        inputs[0] = abi.encode(actions, params);

        swapRouter.execute(commands, inputs, block.timestamp + 1000);

        vm.stopBroadcast();
    }
}
