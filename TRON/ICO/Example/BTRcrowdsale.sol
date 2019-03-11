pragma solidity ^0.4.25;

import './BTRICO.sol';
import './BTRMisc.sol';
import './BTRMultiround.sol';




//TODO - ADD Total TRX raised and Record token wise contribution    
contract TronMarket is ICO,killable,MultiRound  {
   
    

    address ownerMultisig; 
    mapping(address=>uint) blockedTill;    
    
    
    constructor() public{
        ownerMultisig = msg.sender;
        symbol = "BTR";
        name = "Blocktorial";
        decimals = 9;
        multiplier=base**decimals;

        totalSupply = 1000000000*multiplier;// extra 18 zeroes are for the wallets which use decimal variable to show the balance 
        owner = msg.sender;

        balances[owner]=totalSupply;
        currentICOPhase = 1;
        addICOPhase("Phase1",1000000000*multiplier,10000);
        addICOPhase("Phase2",1000000000*multiplier,20000);
        addICOPhase("Phase3",1000000000*multiplier,50000);
        addICOPhase("Phase4",1000000000*multiplier,100000);
        addICOPhase("Phase5",1000000000*multiplier,100000);
        
        runAllocations();
    }

    function runAllocations() ownerOnly public{
        balances[owner]=(totalSupply);
        
    }
   
    function () payable public{
        createTokens();
    }   
   
    
    
    
    function createTokens() payable public{
        ICOPhase storage i = icoPhases[currentICOPhase]; 
        require(i.saleOn == true);
        
        uint256 tokens = msg.value.mul(i.RATE);

        balances[owner] = balances[owner].sub(tokens);
        balances[msg.sender] = balances[msg.sender].add(tokens);
        emit Transfer(owner,msg.sender,tokens);
        i.tokensAllocated = i.tokensAllocated.add(tokens);
        
        totalTokensSoldTillNow = totalTokensSoldTillNow.add(tokens); 
       
        
        trxContributedBy[msg.sender] = trxContributedBy[msg.sender].add(msg.value);
        totalTrxRaised = totalTrxRaised.add(msg.value);
       
        ownerMultisig.transfer(msg.value);

        //Token Disbursement

        
        if(i.tokensAllocated>=i.tokensStaged){
            i.saleOn = !i.saleOn; 
            currentICOPhase++;
        }
        
    }
    
    
    
    function transfer(address _to, uint _value) onlyWhenTokenIsOn onlyPayloadSize(2 * 32) public returns (bool success){
        //_value = _value.mul(1e18);
        require(
            balances[msg.sender]>=_value 
            && _value > 0
            && now > blockedTill[msg.sender]
        );
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit  _to.transferToken(_value,1000686);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint _value) onlyWhenTokenIsOn onlyPayloadSize(3 * 32) public returns (bool success){
        //_value = _value.mul(10**decimals);
        require(
            allowed[_from][msg.sender]>= _value
            && balances[_from] >= _value
            && _value >0 
            && now > blockedTill[_from]            
        );

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit _to.Transfer(_from, _to, _value,1000686);
        return true;
            
    }
    
}
