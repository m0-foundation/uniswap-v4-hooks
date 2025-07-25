// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Surl } from "../../../lib/surl/src/Surl.sol";
import { stdJson } from "../../../lib/forge-std/src/StdJson.sol";

import { PoolKey } from "../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { PredicateMessage } from "../../../lib/predicate-contracts/src/interfaces/IPredicateClient.sol";

import { Deploy } from "../../base/Deploy.s.sol";

contract PredicateHelpers is Deploy {
    using Surl for *;
    using stdJson for string;

    function _getPredicateMessage(
        address caller,
        PoolKey memory poolKey,
        address hook,
        bool zeroForOne,
        int256 amountSpecified
    ) internal returns (PredicateMessage memory) {
        string[] memory headers = new string[](2);
        headers[0] = "Content-Type: application/json";
        headers[1] = string(abi.encodePacked("x-api-key: ", vm.envString("PREDICATE_API_KEY")));

        string memory params = string.concat(
            "{",
            '"from": "',
            vm.toString(caller),
            '", "to": "',
            vm.toString(hook),
            '", "data": "',
            vm.toString(
                abi.encodeWithSignature(
                    "_beforeSwap(address,address,address,uint24,int24,address,bool,int256)",
                    caller,
                    poolKey.currency0,
                    poolKey.currency1,
                    poolKey.fee,
                    poolKey.tickSpacing,
                    hook,
                    zeroForOne,
                    amountSpecified
                )
            ),
            '", "msg_value": "',
            vm.toString(uint256(0)),
            '", "chain_id": ',
            vm.toString(block.chainid),
            " }"
        );

        (uint256 status, bytes memory response) = "https://api.predicate.io/v1/task".post(headers, params);
        string memory json = string(response);

        if (status != 200) {
            revert(string(abi.encodePacked("Predicate API call failed with status: ", vm.toString(status))));
        }

        if (!json.readBool(".is_compliant")) {
            revert("Caller address is non compliant.");
        }

        address[] memory signerAddresses = new address[](1);
        signerAddresses[0] = json.readAddress(".signers[0]");

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = json.readBytes(".signature[0]");

        return
            PredicateMessage({
                taskId: json.readString(".task_id"),
                expireByTime: json.readUint(".expiry_block"),
                signerAddresses: signerAddresses,
                signatures: signatures
            });
    }
}
