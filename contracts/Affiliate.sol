// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Affiliate {
    address authorizedCaller;
    address erc20token;
    //
    mapping(address => uint256) public affiliatesVault;
    mapping(bytes32 => address) public affiliate;
    mapping(address => uint256) public comission;

    constructor(address _authorizedCaller, address _erc20token) public {
        authorizedCaller = _authorizedCaller;
        erc20token = _erc20token;
    }

    // registerDagGraphTier
    function registerAffiliate(
        address affiliateAddress,
        uint256 comission,
        bytes32 identifier
    ) public payable onlyOwner {
        require(affiliate[identifier] == address(0), "Wallet already exists");

        // affiliatesVault[msg.sender] = 0;
        affiliate[identifier] = affiliateAddress;
        comission[affiliateAddress] = comission;
    }

    // withdraws gas token, must be admin
    function withdraw(address payable payee) public {
        // require(owner == msg.sender);
        require(
            affiliatesVault[msg.sender] != 0,
            "Revert, address is not affiliated"
        );
        // uint256 b = address(this).balance;
        require(
            address(this).balance > affiliatesVault[msg.sender],
            "Unsufficient balance"
        );
        (bool sent, bytes memory data) = payee.call{
            value: affiliatesVault[msg.sender]
        }("");
        require(sent, "Failed to send Ether");

        emit Withdrawn(payee, affiliatesVault[msg.sender]);
    }

    // withdraws protocol fee token, must be admin
    function withdrawToken() public payable {
        // require(owner == msg.sender);
        require(
            affiliatesVault[msg.sender] != 0,
            "Revert, address is not affiliated"
        );

        require(
            IERC20(erc20token).balanceOf(address(this)) >
                affiliatesVault[msg.sender],
            "Unsufficient balance"
        );

        // Transfer tokens to pay service fee
        require(
            IERC20(erc20token).transfer(
                msg.sender,
                affiliatesVault[msg.sender]
            ),
            "Transfer failed"
        );

        emit Withdrawn(payee, balance);
    }

    function applyCommission(bytes32 identifier, uint256 price)
        external
        payable
    {
        require(affiliate[identifier] != address(0), "Wallet must exist");
        require(authorizedCaller == msg.sender, "Unauthorized caller");

        uint256 c = commission[affiliate[identifier]] * price;
        require(
            IERC20(erc20token).balanceOf(address(this)) >= c,
            "Not enough funds"
        );
        //TODO: transferFrom external caller to affiliate wallet
        affiliatesVault[affiliate[identifier]] =
            affiliatesVault[affiliate[identifier]] +
            c;
    }
}
