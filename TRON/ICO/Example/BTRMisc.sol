pragma solidity ^0.4.25;

import './BTRICO.sol';

contract killable is ICO {
    
    function killContract() ownerOnly external{
        selfdestruct(ownerMultisig);
    }
}
