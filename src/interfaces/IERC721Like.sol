// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title  ERC721 Like interface.
 * @author M^0 Labs
 */
interface IERC721Like {
    function ownerOf(uint256 tokenId) external view returns (address);

    function setApprovalForAll(address operator, bool approved) external;
}
