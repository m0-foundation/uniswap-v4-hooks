// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.26;

import { CommonBase } from "forge-std/Base.sol";
import { PredicateMessage } from "../../../lib/predicate-contracts/src/interfaces/IPredicateClient.sol";
import { Task } from "../../../lib/predicate-contracts/src/interfaces/IPredicateManager.sol";

import { PoolKey } from "../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

interface IServiceManager {
    function addPermissionedOperators(address[] calldata operators) external;
    function hashTaskWithExpiry(Task memory task) external view returns (bytes32);
}

contract PredicateHelpers is CommonBase {
    /* ============ Helpers ============ */

    function _getPredicateMessage(
        PoolKey memory key,
        string memory taskId,
        string memory policyID,
        address operator,
        uint256 operatorPrivateKey,
        address serviceManager,
        address caller,
        address hook,
        bool zeroForOne,
        int256 amountSpecified
    ) internal view returns (PredicateMessage memory) {
        Task memory task = _getTask(key, taskId, policyID, caller, hook, zeroForOne, amountSpecified);

        return
            PredicateMessage({
                taskId: taskId,
                expireByTime: task.expireByTime,
                signerAddresses: _getSignerAddresses(operator),
                signatures: _getSignatures(task, operatorPrivateKey, serviceManager)
            });
    }

    function _getTask(
        PoolKey memory key,
        string memory taskId,
        string memory policyID,
        address caller,
        address hook,
        bool zeroForOne,
        int256 amountSpecified
    ) internal view returns (Task memory) {
        return
            Task({
                taskId: taskId,
                msgSender: caller,
                target: hook,
                value: 0,
                encodedSigAndArgs: abi.encodeWithSignature(
                    "_beforeSwap(address,address,address,uint24,int24,address,bool,int256)",
                    caller,
                    key.currency0,
                    key.currency1,
                    key.fee,
                    key.tickSpacing,
                    address(key.hooks),
                    zeroForOne,
                    amountSpecified
                ),
                policyID: policyID,
                quorumThresholdCount: 1,
                expireByTime: block.timestamp + 100
            });
    }

    function _getSignerAddresses(address operator) internal pure returns (address[] memory) {
        address[] memory signerAddresses = new address[](1);

        signerAddresses[0] = operator;

        return signerAddresses;
    }

    function _getSignatures(
        Task memory task,
        uint256 operatorPrivateKey,
        address serviceManager
    ) internal view returns (bytes[] memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            operatorPrivateKey,
            IServiceManager(serviceManager).hashTaskWithExpiry(task)
        );

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = abi.encodePacked(r, s, v);

        return signatures;
    }
}
