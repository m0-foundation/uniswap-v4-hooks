// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Ownable } from "../../src/abstract/Ownable.sol";

contract OwnableHarness is Ownable {
    constructor(address initialOwner_) Ownable(initialOwner_) {}
}
