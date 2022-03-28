// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract MintInfo {
    event AddMintInfo(
        address creator,
        string uri,
        uint256 tokenId,
        uint256 royaltyFee
    );

    constructor() {}

    ///
    /// @dev Sets the Mint Information for future lookup. Additionally the indexer
    /// is constantly scaning the blockchain for this event.
    /// @param creator Addres of the nft minter wallet
    /// @param uri Uuid generated on the front end with the uuidv4 library. Uuids are used as a general index.
    /// @param tokenId Token id of the ERC721
    /// @param royaltyFee Royalty fee percentage, must be between 0 to 10000, 1 = 0.01%, 10000 = 100.00%
    ///
    function setMintInfo(
        address creator,
        string memory uri,
        uint256 tokenId,
        uint256 royaltyFee
    ) public {
        emit AddMintInfo(creator, uri, tokenId, royaltyFee);
    }
}
