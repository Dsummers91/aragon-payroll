pragma solidity ^0.4.11;

import './github.com/ConsenSys/Tokens/Token_Contracts/contracts/HumanStandardToken.sol';

// For the sake of simplicity lets asume USD is a ERC20 token
// Also lets asume we can 100% trust the exchange rate oracle
contract DuplicateUSDToken is HumanStandardToken {
  function DuplicateUSDToken() 
    HumanStandardToken(0, "USD", 2,"$") {}


    function transfer(address _to, uint256 _value) returns (bool) {
      balances[_to] += _value;
      Transfer(msg.sender, _to, _value);
      return true;
    }
}