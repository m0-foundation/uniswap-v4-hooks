// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";

import { PredicateMessage } from "../../lib/predicate-contracts/src/interfaces/IPredicateClient.sol";

import { IAllowanceTransfer } from "../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { Currency, CurrencyLibrary } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { BalanceDelta } from "../../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";

import { IUniversalRouterLike } from "../../test/utils/interfaces/IUniversalRouterLike.sol";

import { Config } from "../base/Config.sol";

import { PredicateHelpers } from "./helpers/PredicateHelpers.sol";

interface IUsualM {
    function wrap(address recipient, uint256 amount) external returns (uint256);
}

contract FlashSwap is Config, PredicateHelpers {
    using CurrencyLibrary for Currency;

    function run() public {
        address caller = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address hook = vm.envAddress("UNISWAP_HOOK");

        int24 tickLowerBound = int24(vm.envInt("TICK_LOWER_BOUND"));
        int24 tickUpperBound = int24(vm.envInt("TICK_UPPER_BOUND"));

        DeployConfig memory config = _getDeployConfig(
            block.chainid,
            WRAPPED_M,
            USDC_ETHEREUM,
            tickLowerBound,
            tickUpperBound
        );

        PoolKey memory poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            hooks: IHooks(hook)
        });

        PredicateMessage memory predicateMessage = _getPredicateMessage(caller, poolKey, hook, false, 1e6);

        vm.startBroadcast(caller);

        FlashSwapExecutor flashSwap = new FlashSwapExecutor(hook);

        // Approve the FlashSwap contract to spend USDC
        IERC20(USDC_ETHEREUM).approve(address(flashSwap), type(uint256).max);

        flashSwap.execute(1e6, predicateMessage);

        vm.stopBroadcast();
    }
}

/**
 * @title FlashSwapExecutor
 * @dev This contract borrows Wrapped M from the Pool Manager, wraps it into UsualM,
 *      swaps USDC for Wrapped M to repay the flashloan and then self-destructs.
 * @dev The contract needs to be added to the AllowlistHook's trusted Swap Routers to be able to execute the swap.
 */
contract FlashSwapExecutor is Config {
    using CurrencyLibrary for Currency;

    /// @notice Thrown when attempting to reenter a locked function from an external caller
    error ContractLocked();

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPoolManager public constant POOL_MANAGER = IPoolManager(POOL_MANAGER_ETHEREUM);

    address public constant USUAL_M = 0x4Cbc25559DbBD1272EC5B64c7b5F48a2405e6470;

    /// @dev Needed to pass the msg.sender check in the AllowlistHook.
    address public immutable msgSender;
    PoolKey public poolKey;
    IUniversalRouterLike public immutable swapRouter;

    constructor(address hook) {
        DeployConfig memory config = _getDeployConfig(block.chainid, WRAPPED_M, USDC_ETHEREUM, -1, 1);

        msgSender = msg.sender;
        poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            hooks: IHooks(hook)
        });

        swapRouter = IUniversalRouterLike(config.swapRouter);
    }

    function execute(uint128 wrapAmount, PredicateMessage memory predicateMessage) external {
        // Flashloan USDC
        POOL_MANAGER.unlock(abi.encode(msg.sender, wrapAmount, predicateMessage));

        // Destroy the contract after the flashloan is executed
        selfdestruct(payable(msg.sender));
    }

    /**
     * @notice Callback to handle the flashloan.
     * @param data The encoded caller address.
     * @return retdata Arbitrary data (implicit return).
     */
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        // Decode the flashloan data from the lock data
        (address caller, uint128 wrapAmount, PredicateMessage memory predicateMessage) = abi.decode(
            data,
            (address, uint128, PredicateMessage)
        );

        // Call the internal handler
        return _handleFlashloan(caller, wrapAmount, predicateMessage);
    }

    function _handleFlashloan(
        address caller,
        uint128 wrapAmount,
        PredicateMessage memory predicateMessage
    ) internal virtual returns (bytes memory) {
        // Swap USDC for Wrapped M
        BalanceDelta swapDelta = POOL_MANAGER.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: int256(uint256(wrapAmount)),
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(1)
            }),
            abi.encode(predicateMessage)
        );

        // Sync the USDC balance before repayment
        POOL_MANAGER.sync(Currency.wrap(USDC_ETHEREUM));

        // Transfer USDC from caller to repay flashloan
        IERC20(USDC_ETHEREUM).transferFrom(caller, address(POOL_MANAGER), uint256(-int256(swapDelta.amount1())));

        // Settle the balance after repayment
        POOL_MANAGER.settle();

        // Take Wrapped M after the swap
        POOL_MANAGER.take(Currency.wrap(WRAPPED_M), address(this), uint256(int256(swapDelta.amount0())));

        // Wrap Wrapped M for UsualM
        IERC20(WRAPPED_M).approve(USUAL_M, type(uint256).max);
        IUsualM(USUAL_M).wrap(caller, wrapAmount);

        return new bytes(0);
    }
}
