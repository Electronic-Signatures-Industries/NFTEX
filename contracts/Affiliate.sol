// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Affiliate  {

  //
  mapping(address => uint256) public affiliatesVault;
  mapping (bytes32 => address) public affiliate;
  mapping (address => uint256) public comission;
  
  constructor (type name) public {
    
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
      require(affiliatesVault[msg.sender] != 0, "Revert, address is not affiliated");
      uint256 b = address(this).balance;
      (bool sent, bytes memory data) = payee.call{value: b}("");
      require(sent, "Failed to send Ether");

      emit Withdrawn(payee, b);
  }

  // withdraws protocol fee token, must be admin
  function withdrawToken(address payable payee, address erc20token) public {
      // require(owner == msg.sender);
      require(affiliatesVault[msg.sender] != 0, "Revert, address is not affiliated");
      uint256 balance = IERC20(erc20token).balanceOf(address(this));

      // Transfer tokens to pay service fee
      require(IERC20(erc20token).transfer(payee, balance), "transfer failed");

      emit Withdrawn(payee, balance);
  }
}