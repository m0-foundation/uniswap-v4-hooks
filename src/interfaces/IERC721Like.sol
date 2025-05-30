// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

/**
 * @title  ERC721 Like interface.
 * @author M0 Labs
 */
interface IERC721Like {
    function ownerOf(uint256 tokenId) external view returns (address);

    function setApprovalForAll(address operator, bool approved) external;
}
