// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { AllowlistHook } from "../../src/AllowlistHook.sol";

contract AllowlistHookHarness is AllowlistHook {
    function setTotalSwap(uint256 totalSwap_) external {
        totalSwap = totalSwap_;
    }

    function setToken0Decimals(uint8 decimals_) external {
        _token0Decimals = decimals_;
    }

    function setToken1Decimals(uint8 decimals_) external {
        _token1Decimals = decimals_;
    }

    function tokenAmountToDecimals(
        uint256 tokenAmount_,
        uint8 tokenDecimals_,
        uint8 targetDecimals_
    ) external pure returns (uint256) {
        return _tokenAmountToDecimals(tokenAmount_, tokenDecimals_, targetDecimals_);
    }
}
