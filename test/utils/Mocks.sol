// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract Foo {
    function bar() external pure returns (uint256) {
        return 1;
    }
}

contract Migrator {
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public immutable implementationV2;

    constructor(address implementation_) {
        implementationV2 = implementation_;
    }

    fallback() external virtual {
        address implementation_ = implementationV2;

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }
    }
}

contract MockRegistrar {
    mapping(bytes32 key => bytes32 value) public get;

    mapping(bytes32 list => mapping(address account => bool contains)) public listContains;

    function set(bytes32 key_, bytes32 value_) external {
        get[key_] = value_;
    }

    function setListContains(bytes32 list_, address account_, bool contains_) external {
        listContains[list_][account_] = contains_;
    }
}
