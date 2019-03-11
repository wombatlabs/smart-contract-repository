pragma solidity ^0.4.25;

import './BTRICO.sol';

contract MultiRound is ICO{
    function newICORound(uint256 _newSupply) ownerOnly public{//This is different from Stages which means multiple parts of one round
        _newSupply = _newSupply.mul(multiplier);
        balances[owner] = balances[owner].add(_newSupply);
        totalSupply = totalSupply.add(_newSupply);
    }

    function destroyUnsoldTokens(uint256 _tokens) ownerOnly public{
        _tokens = _tokens.mul(multiplier);
        totalSupply = totalSupply.sub(_tokens);
        balances[owner] = balances[owner].sub(_tokens);
    }

    
}
