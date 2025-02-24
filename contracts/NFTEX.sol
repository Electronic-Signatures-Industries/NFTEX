// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NFTEX is ERC721Holder, Ownable {
  using SafeERC20 for IERC20;
  enum OrderType {
    Fixed,
    Dutch,
    English
  }

  struct Order {
    OrderType orderType;  //0:Fixed Price, 1:Dutch Auction, 2:English Auction
    address seller;
    IERC721Metadata token;
    uint256 tokenId;
    uint256 startPrice;
    uint256 endPrice;
    uint256 startBlock;
    uint256 endBlock;
    uint256 lastBidPrice;
    address lastBidder;
    bool isSold;
    address creator;
    uint256 royaltyFeePercent;
  }

  mapping (IERC721Metadata => mapping (uint256 => bytes32[])) public orderIdByToken;
  mapping (address => bytes32[]) public orderIdBySeller;
  mapping (bytes32 => Order) public orderInfo;
  // mapping (address => monto) public account;

  address public feeAddress;
  uint16 public feePercent;
  IERC20 public nativeCoin;

  event MakeOrder(IERC721Metadata indexed token, uint256 id, bytes32 indexed hash, address seller, string uri, uint256 timestamp, uint256 price);
  event CancelOrder(IERC721Metadata indexed token, uint256 id, bytes32 indexed hash, address seller, string uri);
  event Bid(IERC721Metadata indexed token, uint256 id, bytes32 indexed hash, address bidder, uint256 bidPrice, string uri);
  event Claim(IERC721Metadata indexed token, uint256 id, bytes32 indexed hash, address seller, address taker, uint256 price, string uri);
  event GiveReward(address operator, address from, uint256 tokenId, IERC721Metadata nft);
  event Withdrawn(address indexed paymentAddress, uint256 amount);

  constructor(
    address tokenERC20,
    uint16 _feePercent) {
    require(_feePercent <= 10000, "input value is more than 100%");
    feeAddress = msg.sender;
    feePercent = _feePercent;
    nativeCoin = IERC20(tokenERC20);
  }

    ///
    /// @dev gets the current price of an order
    /// @param _order Id of the order 
    /// @return price of the order according to order type
    /// 
  function getCurrentPrice(bytes32 _order) public view returns (uint256) {
    Order storage o = orderInfo[_order];
    OrderType orderType = o.orderType;
    if (orderType == OrderType.Fixed) {
      return o.startPrice;
    } else if (orderType == OrderType.English) {
      uint256 lastBidPrice = o.lastBidPrice;
      return lastBidPrice == 0 ? o.startPrice : lastBidPrice;
    } else {
      uint256 _startPrice = o.startPrice;
      uint256 _startBlock = o.startBlock;
      uint256 tickPerBlock = (_startPrice - o.endPrice) / (o.endBlock - _startBlock);
      return _startPrice - ((block.number - _startBlock) * tickPerBlock);
    }
  }

  function sellerOrderLength(address _seller) external view returns (uint256) {
    return orderIdBySeller[_seller].length;
  }

  // make order fx
  //0:Fixed Price, 1:Dutch Auction, 2:English Auction
  function dutchAuction(IERC721Metadata _token, uint256 _id, uint256 _startPrice, uint256 _endPrice, uint256 _endBlock) public {
    require(_startPrice > _endPrice, "End price should be lower than start price");
    _makeOrder(OrderType.Dutch, _token, _id, _startPrice, _endPrice, _endBlock);
  }  //sp != ep

  function englishAuction(IERC721Metadata _token, uint256 _id, uint256 _startPrice, uint256 _endBlock) public {
    _makeOrder(OrderType.English, _token, _id, _startPrice, 0, _endBlock);
  } //ep=0. for gas saving.

  function fixedPrice(IERC721Metadata _token, uint256 _id, uint256 _price, uint256 _endTimestamp) public {
    _makeOrder(OrderType.Fixed, _token, _id, _price, 0, _endTimestamp);
  }  //ep=0. for gas saving.

  function _makeOrder(
    OrderType _orderType,
    IERC721Metadata _token,
    uint256 _id,
    uint256 _startPrice,
    uint256 _endPrice,
    uint256 _endTimestamp
  ) internal {
    require(_endTimestamp > block.timestamp, "Duration must be more than zero");
    require(_startPrice > 0, "Price must be more than zero");
    
    //push
    bytes32 hash = _hash(_token, _id, msg.sender);

    address _creator = IAnconNFT(address(_token)).getCreator(_id);
    uint256 _royaltyFeePercent = IAnconNFT(address(_token)).getRoyaltyFee(_id);
    orderInfo[hash] = Order(
        _orderType, 
        msg.sender, 
        _token, 
        _id, 
        _startPrice, 
        _endPrice, 
        block.timestamp, 
        _endTimestamp, 
        0, 
        address(0), 
        false, 
        _creator, 
        _royaltyFeePercent
      );
    orderIdByToken[_token][_id].push(hash);
    orderIdBySeller[msg.sender].push(hash);

    //check if seller has a right to transfer the NFT token. safeTransferFrom.
    _token.safeTransferFrom(msg.sender, address(this), _id);

    // IERC721Metadata tokenStorage = _token;
    string memory uri = _token.tokenURI(_id);
    // TODO: Event register token airdrop
    // emit ERC721Recerived(operator, from, tokenId, data)
    
    emit MakeOrder(_token, _id, hash, msg.sender, uri, _endTimestamp, _startPrice);
    emit GiveReward(feeAddress, msg.sender, _id, _token);
  }

  function _hash(IERC721Metadata _token, uint256 _id, address _seller) internal view returns (bytes32) {
    return keccak256(abi.encodePacked(block.timestamp, _token, _id, _seller));
  }

  function buyItNow(bytes32 _order) payable external {
    Order storage o = orderInfo[_order];
    uint256 endBlock = o.endBlock;
    require(endBlock != 0, "Order has ended");
    require(endBlock > block.timestamp, "Time limit its over");
    require(o.orderType == OrderType.Fixed, "Invalid order type, Its not a fix price order");
    require(o.isSold == false, "Has already been sold");

    uint256 currentPrice = getCurrentPrice(_order);

    // verify blockchain native token utilization
    // require(msg.value >= currentPrice, "price error");

    o.isSold = true;    //reentrancy proof

    uint256 fee = (currentPrice * feePercent) / 10000;
    uint256 royaltyFee = (currentPrice * o.royaltyFeePercent) /10000;
    uint256 balance = nativeCoin.balanceOf(msg.sender);
    uint256 totalAmount = currentPrice - royaltyFee - fee;

    if(o.creator == o.seller) {
      royaltyFee = 0;
      totalAmount = currentPrice - fee;
    }


    require(balance >= currentPrice, "Sender balance is too low");
    require(nativeCoin.allowance(msg.sender, address(this)) >= currentPrice, "Balance not allowed");
    nativeCoin.safeTransferFrom(msg.sender, address(this), currentPrice);
    nativeCoin.safeTransfer(feeAddress, fee);
    
    //Royalty Fee payment
    if(o.creator != o.seller) {
      nativeCoin.safeTransfer(o.creator, royaltyFee);
    }

    nativeCoin.safeTransfer(o.seller, totalAmount);

    o.token.safeTransferFrom(address(this), msg.sender, o.tokenId);

    emit Claim(o.token, o.tokenId, _order, o.seller, msg.sender, currentPrice, o.token.tokenURI(o.tokenId));
  }

  function cancelOrder(bytes32 _order) external {
    Order storage o = orderInfo[_order];
    require(o.seller == msg.sender, "Access denied");
    require(o.lastBidPrice == 0, "Bidding exist"); //for EA. but even in DA, FP, seller can withdraw his/her token with this fx.
    require(o.isSold == false, "Already sold");

    IERC721Metadata token = o.token;
    uint256 tokenId = o.tokenId;

    o.endBlock = 0;   //0 endBlock means the order was canceled.

    string memory uri = token.tokenURI(tokenId);

    token.safeTransferFrom(address(this), msg.sender, tokenId);
    emit CancelOrder(token, tokenId, _order, msg.sender, uri);
  }

  //feeAddress must be either an EOA or a contract must have payable receive fx and doesn't have some codes in that fx.
  //If not, it might be that it won't be receive any fee.
  function setFeeAddress(address _feeAddress) external onlyOwner {
    feeAddress = _feeAddress;
  }

  function setFeePercent(uint16 _percent) external onlyOwner {
    require(_percent <= 10000, "input value is more than 100%");
    feePercent = _percent;
  }

  function withdrawBalance(address payable payee) public onlyOwner {
    uint256 balance = nativeCoin.balanceOf(address(this));

    require(nativeCoin.transfer(payee, balance), "NFTEX: Transfer failed");

    emit Withdrawn(payee, balance);
  }

}

abstract contract IAnconNFT {
  function getCreator(uint256 id) virtual external view returns(address);
  function getRoyaltyFee(uint256 id) virtual external view returns(uint256);
}